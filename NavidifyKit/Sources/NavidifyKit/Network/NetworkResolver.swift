import Foundation
import Network
import CryptoKit

public actor NetworkResolver {
    public static let shared = NetworkResolver()

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.navidify.networkresolver")

    private var cachedBaseUrl: String?
    private var currentMode: ConnectionMode = .reconnecting
    private var isMonitoring = false

    public typealias StateHandler = @Sendable (ConnectionMode, String?) -> Void
    private var listeners: [UUID: StateHandler] = [:]

    public init() {}

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { [weak self] in
                guard let self = self else { return }
                // Proactively test connection whenever network path changes
                _ = try? await self.resolveBaseUrl(forceRecheck: true)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    public func stopMonitoring() {
        pathMonitor.cancel()
        isMonitoring = false
    }

    public func addListener(_ handler: @escaping StateHandler) -> UUID {
        let id = UUID()
        listeners[id] = handler
        handler(currentMode, cachedBaseUrl)
        return id
    }

    public func removeListener(id: UUID) {
        listeners.removeValue(forKey: id)
    }

    public func getCurrentStatus() -> (mode: ConnectionMode, baseUrl: String?) {
        return (currentMode, cachedBaseUrl)
    }

    private func updateState(mode: ConnectionMode, url: String?) {
        self.currentMode = mode
        self.cachedBaseUrl = url
        for listener in listeners.values {
            listener(mode, url)
        }
    }

    public func buildAuthQueryItems(username: String, password: String) -> [URLQueryItem] {
        let salt = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
        let raw = password + salt
        let token = Insecure.MD5.hash(data: Data(raw.utf8)).map { String(format: "%02hhx", $0) }.joined()

        return [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: String(salt)),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "Navidify"),
            URLQueryItem(name: "f", value: "json")
        ]
    }

    public func pingUrl(baseUrl: String, username: String, password: String, timeout: TimeInterval) async -> Bool {
        guard var components = URLComponents(string: baseUrl) else { return false }
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += "rest/ping.view"
        components.path = path
        components.queryItems = buildAuthQueryItems(username: username, password: password)

        guard let url = components.url else { return false }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        let ephemeralSession = URLSession(configuration: config)

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let ok = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                do {
                    let (data, response) = try await ephemeralSession.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        print("[NetworkResolver] Ping failed for \(url.host ?? ""): HTTP \(status)")
                        return false
                    }
                    let decoded = try JSONDecoder().decode(SubsonicContainer<PingResponse>.self, from: data)
                    let isOk = decoded.subsonicResponse.status.lowercased() == "ok"
                    print("[NetworkResolver] Ping response for \(url.host ?? ""): \(decoded.subsonicResponse.status)")
                    return isOk
                } catch {
                    print("[NetworkResolver] Ping error for \(url.host ?? ""): \(error.localizedDescription)")
                    return false
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return false
            }

            for await result in group {
                if result {
                    group.cancelAll()
                    return true
                }
            }
            return false
        }
        ephemeralSession.finishTasksAndInvalidate()
        return ok
    }

    public func resolveBaseUrl(forceRecheck: Bool = false) async throws -> String {
        if !forceRecheck, let cached = cachedBaseUrl, currentMode != .offline {
            return cached
        }

        updateState(mode: .reconnecting, url: cachedBaseUrl)

        let lanUrl = (KeychainHelper.load(key: .lanUrl) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let tailscaleUrl = (KeychainHelper.load(key: .tailscaleUrl) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let username = KeychainHelper.load(key: .username) ?? ""
        let password = KeychainHelper.load(key: .password) ?? ""

        print("[NetworkResolver] resolve: lan='\(lanUrl)' ts='\(tailscaleUrl)' u='\(username)' pLen=\(password.count)")

        guard !username.isEmpty, !password.isEmpty else {
            updateState(mode: .offline, url: nil)
            throw NSError(domain: "NavidifyNetwork", code: 401, userInfo: [NSLocalizedDescriptionKey: "Credentials not configured in Settings."])
        }

        // Test LAN (fast 1.5s timeout) and Tailscale (4.0s timeout) concurrently
        let results = await withTaskGroup(of: (ConnectionMode, String, Bool).self) { group -> [(ConnectionMode, String, Bool)] in
            if !lanUrl.isEmpty {
                group.addTask {
                    let ok = await self.pingUrl(baseUrl: lanUrl, username: username, password: password, timeout: 1.5)
                    return (.lan, lanUrl, ok)
                }
            }
            if !tailscaleUrl.isEmpty {
                group.addTask {
                    let ok = await self.pingUrl(baseUrl: tailscaleUrl, username: username, password: password, timeout: 4.0)
                    return (.tailscale, tailscaleUrl, ok)
                }
            }

            var res: [(ConnectionMode, String, Bool)] = []
            for await item in group {
                res.append(item)
            }
            return res
        }

        // Priority 1: LAN if successful
        if let lanSuccess = results.first(where: { $0.0 == .lan && $0.2 }) {
            updateState(mode: .lan, url: lanSuccess.1)
            return lanSuccess.1
        }

        // Priority 2: Tailscale if successful
        if let tsSuccess = results.first(where: { $0.0 == .tailscale && $0.2 }) {
            updateState(mode: .tailscale, url: tsSuccess.1)
            return tsSuccess.1
        }

        // If neither ping succeeded, mark offline and throw
        updateState(mode: .offline, url: nil)
        throw NSError(
            domain: "NavidifyNetwork",
            code: -1009,
            userInfo: [NSLocalizedDescriptionKey: "Server unreachable via LAN and Tailscale. Please verify your network connection or Tailscale VPN."]
        )
    }
}
