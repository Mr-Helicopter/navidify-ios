import Foundation

public actor NavidromeClient {
    public static let shared = NavidromeClient()

    private let resolver = NetworkResolver.shared
    private let session: URLSession

    // Native Navidrome JWT token state
    private var nativeJwtToken: String?
    private var jwtExpiresAt: Date?

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 20.0
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Subsonic Request Handling

    public func subsonicFetch<T: Codable & Sendable>(
        endpoint: String,
        extraParams: [String: String?] = [:],
        isRetry: Bool = false
    ) async throws -> T {
        let baseUrl = try await resolver.resolveBaseUrl(forceRecheck: false)
        guard let username = KeychainHelper.load(key: .username),
              let password = KeychainHelper.load(key: .password) else {
            throw NSError(domain: "NavidromeClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing username or password in Keychain."])
        }

        guard var components = URLComponents(string: baseUrl) else {
            throw NSError(domain: "NavidromeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL: \(baseUrl)"])
        }

        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += "rest/\(endpoint)"
        components.path = path

        var queryItems = await resolver.buildAuthQueryItems(username: username, password: password)
        for (key, val) in extraParams {
            if let val = val {
                queryItems.append(URLQueryItem(name: key, value: val))
            }
        }
        components.queryItems = queryItems

        guard let requestUrl = components.url else {
            throw NSError(domain: "NavidromeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct request URL."])
        }

        var request = URLRequest(url: requestUrl)
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "NavidromeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "NavidromeClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode)"])
            }

            // Check if Subsonic returned a failed status header
            if let generic = try? JSONDecoder().decode(SubsonicContainer<SubsonicResponseHeader>.self, from: data) {
                if generic.subsonicResponse.status.lowercased() == "failed" {
                    let errMsg = generic.subsonicResponse.error?.message ?? "Subsonic API request failed"
                    let code = generic.subsonicResponse.error?.code ?? -1
                    throw NSError(domain: "NavidromeSubsonic", code: code, userInfo: [NSLocalizedDescriptionKey: errMsg])
                }
            }

            let decoded = try JSONDecoder().decode(SubsonicContainer<T>.self, from: data)
            return decoded.subsonicResponse
        } catch {
            if !isRetry {
                // Re-evaluate network on failure
                do {
                    _ = try await resolver.resolveBaseUrl(forceRecheck: true)
                    return try await subsonicFetch(endpoint: endpoint, extraParams: extraParams, isRetry: true)
                } catch {
                    throw error
                }
            }
            throw error
        }
    }

    // MARK: - URLs for Media & Images

    public func getStreamUrl(songId: String) async -> URL? {
        guard let baseUrl = try? await resolver.resolveBaseUrl(forceRecheck: false),
              let username = KeychainHelper.load(key: .username),
              let password = KeychainHelper.load(key: .password) else {
            return nil
        }

        guard var components = URLComponents(string: baseUrl) else { return nil }
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += "rest/stream.view"
        components.path = path

        var queryItems = await resolver.buildAuthQueryItems(username: username, password: password)
        queryItems.append(URLQueryItem(name: "id", value: songId))
        components.queryItems = queryItems
        return components.url
    }

    public func getCoverArtUrl(id: String?, size: Int = 300) async -> URL? {
        guard let id = id, !id.isEmpty,
              let baseUrl = try? await resolver.resolveBaseUrl(forceRecheck: false),
              let username = KeychainHelper.load(key: .username),
              let password = KeychainHelper.load(key: .password) else {
            return nil
        }

        guard var components = URLComponents(string: baseUrl) else { return nil }
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += "rest/getCoverArt.view"
        components.path = path

        var queryItems = await resolver.buildAuthQueryItems(username: username, password: password)
        queryItems.append(URLQueryItem(name: "id", value: id))
        queryItems.append(URLQueryItem(name: "size", value: String(size)))
        components.queryItems = queryItems
        return components.url
    }

    public func getArtistImageUrl(id: String?, size: Int = 300) async -> URL? {
        guard let id = id, !id.isEmpty,
              let baseUrl = try? await resolver.resolveBaseUrl(forceRecheck: false),
              let username = KeychainHelper.load(key: .username),
              let password = KeychainHelper.load(key: .password) else {
            return nil
        }

        guard var components = URLComponents(string: baseUrl) else { return nil }
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += "rest/getAvatar.view"
        components.path = path

        var queryItems = await resolver.buildAuthQueryItems(username: username, password: password)
        queryItems.append(URLQueryItem(name: "id", value: id))
        queryItems.append(URLQueryItem(name: "size", value: String(size)))
        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Subsonic Endpoints

    public func ping() async throws -> PingResponse {
        return try await subsonicFetch(endpoint: "ping.view")
    }

    public func getAlbumList2(
        type: String = "newest",
        size: Int = 20,
        offset: Int = 0,
        genre: String? = nil
    ) async throws -> [Album] {
        var params: [String: String?] = [
            "type": type,
            "size": String(size),
            "offset": String(offset)
        ]
        if let genre = genre {
            params["genre"] = genre
        }
        let res: AlbumList2Response = try await subsonicFetch(endpoint: "getAlbumList2.view", extraParams: params)
        return res.albumList2?.album ?? []
    }

    public func getArtists() async throws -> [Artist] {
        let res: ArtistsResponse = try await subsonicFetch(endpoint: "getArtists.view")
        let indexes = res.artists?.index ?? []
        return indexes.flatMap { $0.artist ?? [] }
    }

    public func getArtist(id: String) async throws -> Artist? {
        let res: ArtistDetailResponse = try await subsonicFetch(endpoint: "getArtist.view", extraParams: ["id": id])
        return res.artist
    }

    public func getAlbum(id: String) async throws -> Album? {
        let res: AlbumDetailResponse = try await subsonicFetch(endpoint: "getAlbum.view", extraParams: ["id": id])
        return res.album
    }

    public func getGenres() async throws -> [Genre] {
        let res: GenresResponse = try await subsonicFetch(endpoint: "getGenres.view")
        return res.genres?.genre ?? []
    }

    public func getStarred2() async throws -> (songs: [Song], albums: [Album], artists: [Artist]) {
        let res: Starred2Response = try await subsonicFetch(endpoint: "getStarred2.view")
        let songs = res.starred2?.song ?? []
        let albums = res.starred2?.album ?? []
        let artists = res.starred2?.artist ?? []
        return (songs, albums, artists)
    }

    public func star(id: String, type: String = "song") async throws {
        let paramKey = type == "album" ? "albumId" : (type == "artist" ? "artistId" : "id")
        let _: SubsonicResponseHeader = try await subsonicFetch(endpoint: "star.view", extraParams: [paramKey: id])
    }

    public func unstar(id: String, type: String = "song") async throws {
        let paramKey = type == "album" ? "albumId" : (type == "artist" ? "artistId" : "id")
        let _: SubsonicResponseHeader = try await subsonicFetch(endpoint: "unstar.view", extraParams: [paramKey: id])
    }

    public func search3(query: String) async throws -> (songs: [Song], albums: [Album], artists: [Artist]) {
        let res: SearchResult3Response = try await subsonicFetch(
            endpoint: "search3.view",
            extraParams: [
                "query": query,
                "artistCount": "10",
                "albumCount": "15",
                "songCount": "25"
            ]
        )
        return (
            res.searchResult3?.song ?? [],
            res.searchResult3?.album ?? [],
            res.searchResult3?.artist ?? []
        )
    }

    public func getPlaylists() async throws -> [Playlist] {
        let res: PlaylistsResponse = try await subsonicFetch(endpoint: "getPlaylists.view")
        return res.playlists?.playlist ?? []
    }

    public func getPlaylist(id: String) async throws -> Playlist? {
        let res: PlaylistDetailResponse = try await subsonicFetch(endpoint: "getPlaylist.view", extraParams: ["id": id])
        return res.playlist
    }

    public func createPlaylist(name: String, songIds: [String] = []) async throws -> Playlist? {
        let params: [String: String?] = [
            "name": name,
            "songId": songIds.isEmpty ? nil : songIds.joined(separator: ",")
        ]
        let res: PlaylistDetailResponse = try await subsonicFetch(endpoint: "createPlaylist.view", extraParams: params)
        return res.playlist
    }

    public func updatePlaylist(
        playlistId: String,
        name: String? = nil,
        comment: String? = nil,
        publicPlay: Bool? = nil,
        songIdsToAdd: [String]? = nil,
        songIndexesToRemove: [Int]? = nil
    ) async throws {
        var params: [String: String?] = [
            "playlistId": playlistId,
            "name": name,
            "comment": comment,
            "public": publicPlay != nil ? String(publicPlay!) : nil
        ]
        if let toAdd = songIdsToAdd, !toAdd.isEmpty {
            params["songIdToAdd"] = toAdd.joined(separator: ",")
        }
        if let toRemove = songIndexesToRemove, !toRemove.isEmpty {
            params["songIndexToRemove"] = toRemove.map(String.init).joined(separator: ",")
        }
        let _: SubsonicResponseHeader = try await subsonicFetch(endpoint: "updatePlaylist.view", extraParams: params)
    }

    public func deletePlaylist(id: String) async throws {
        let _: SubsonicResponseHeader = try await subsonicFetch(endpoint: "deletePlaylist.view", extraParams: ["id": id])
    }

    public func scrobble(id: String, submission: Bool = true) async throws {
        let _: SubsonicResponseHeader = try await subsonicFetch(
            endpoint: "scrobble.view",
            extraParams: [
                "id": id,
                "submission": String(submission)
            ]
        )
    }

    public func getLyrics(songId: String, artist: String? = nil, title: String? = nil) async -> [ParsedLyricLine] {
        // 1. Try structured lyrics by Song ID
        if let res: LyricsResponse = try? await subsonicFetch(endpoint: "getLyricsBySongId.view", extraParams: ["id": songId]),
           let structured = res.lyricsList?.structuredLyrics?.first,
           let lines = structured.line, !lines.isEmpty {
            return lines.compactMap { line in
                guard let start = line.start else { return nil }
                return ParsedLyricLine(time: start / 1000.0, text: line.value)
            }.sorted { $0.time < $1.time }
        }

        // 2. Try plain lyrics
        if let artist = artist, let title = title,
           let res: PlainLyricsResponse = try? await subsonicFetch(endpoint: "getLyrics.view", extraParams: ["artist": artist, "title": title]),
           let raw = res.lyrics?.value, !raw.isEmpty {
            return parseLrc(lrcText: raw)
        }

        return []
    }

    public func parseLrc(lrcText: String) -> [ParsedLyricLine] {
        guard !lrcText.isEmpty else { return [] }
        var result: [ParsedLyricLine] = []
        let lines = lrcText.components(separatedBy: .newlines)

        let regex = try? NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.?(\\d{2,3})?\\](.*)")

        for line in lines {
            let nsLine = line as NSString
            let matches = regex?.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) ?? []
            for match in matches where match.numberOfRanges >= 5 {
                let minutesStr = nsLine.substring(with: match.range(at: 1))
                let secondsStr = nsLine.substring(with: match.range(at: 2))
                var millis: Double = 0
                if match.range(at: 3).location != NSNotFound {
                    let millisStr = nsLine.substring(with: match.range(at: 3)).padding(toLength: 3, withPad: "0", startingAt: 0)
                    millis = Double(millisStr) ?? 0
                }
                let text = nsLine.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)

                let totalSeconds = (Double(minutesStr) ?? 0) * 60.0 + (Double(secondsStr) ?? 0) + (millis / 1000.0)
                if !text.isEmpty {
                    result.append(ParsedLyricLine(time: totalSeconds, text: text))
                }
            }
        }

        return result.sorted { $0.time < $1.time }
    }

    // MARK: - Navidrome Native REST API & Folder-to-Smart-Playlist Sync

    public func getNativeToken(forceRefresh: Bool = false) async throws -> String {
        let now = Date()
        if !forceRefresh, let token = nativeJwtToken, let expires = jwtExpiresAt, now < expires {
            return token
        }

        let baseUrl = try await resolver.resolveBaseUrl(forceRecheck: false)
        guard let username = KeychainHelper.load(key: .username),
              let password = KeychainHelper.load(key: .password) else {
            throw NSError(domain: "NavidromeClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing credentials."])
        }

        guard let loginUrl = URL(string: "\(baseUrl)/auth/login") else {
            throw NSError(domain: "NavidromeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid login URL"])
        }

        var request = URLRequest(url: loginUrl)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "NavidromeClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "Native Navidrome login failed."])
        }

        let decoded = try JSONDecoder().decode(NavidromeLoginResponse.self, from: data)
        self.nativeJwtToken = decoded.token
        // Cache token for 11 hours (server typically sets 12h) to proactively avoid expiration
        self.jwtExpiresAt = now.addingTimeInterval(11 * 3600)
        return decoded.token
    }

    public func syncFoldersToPlaylists() async {
        do {
            let token = try await getNativeToken()
            let baseUrl = try await resolver.resolveBaseUrl(forceRecheck: false)

            var headers = [
                "x-nd-authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]

            // 1. Fetch existing playlists in Navidrome
            guard let playlistsUrl = URL(string: "\(baseUrl)/api/playlist") else { return }
            var plRequest = URLRequest(url: playlistsUrl)
            plRequest.timeoutInterval = 10.0
            headers.forEach { plRequest.setValue($1, forHTTPHeaderField: $0) }

            var (plData, plResponse) = try await session.data(for: plRequest)
            if let http = plResponse as? HTTPURLResponse, http.statusCode == 401 {
                // Reactive retry on 401: obtain fresh token and retry once
                let freshToken = try await getNativeToken(forceRefresh: true)
                headers["x-nd-authorization"] = "Bearer \(freshToken)"
                plRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "x-nd-authorization")
                (plData, plResponse) = try await session.data(for: plRequest)
            }

            guard let httpPl = plResponse as? HTTPURLResponse, (200...299).contains(httpPl.statusCode) else {
                return
            }

            let existingPlaylists = (try? JSONDecoder().decode([NavidromeNativePlaylist].self, from: plData)) ?? []
            let existingNames = Set(existingPlaylists.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

            // 2. Fetch songs to detect distinct directory names
            guard let songsUrl = URL(string: "\(baseUrl)/api/song?_start=0&_end=5000") else { return }
            var songsRequest = URLRequest(url: songsUrl)
            songsRequest.timeoutInterval = 15.0
            headers.forEach { songsRequest.setValue($1, forHTTPHeaderField: $0) }

            let (songsData, songsResponse) = try await session.data(for: songsRequest)
            guard let httpSongs = songsResponse as? HTTPURLResponse, (200...299).contains(httpSongs.statusCode) else {
                return
            }

            let songs = (try? JSONDecoder().decode([NavidromeNativeSong].self, from: songsData)) ?? []
            var distinctFolders = Set<String>()
            for song in songs {
                if let path = song.path, path.contains("/") {
                    let parts = path.split(separator: "/")
                    if let first = parts.first {
                        let topFolder = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !topFolder.isEmpty && topFolder != "." {
                            distinctFolders.insert(topFolder)
                        }
                    }
                }
            }

            // 3. For any folder that doesn't have a playlist yet, create a Smart Playlist
            for folder in distinctFolders {
                if !existingNames.contains(folder.lowercased()) {
                    let payload = NavidromeCreateSmartPlaylistPayload(
                        name: folder,
                        comment: "Auto-synced from folder '\(folder)'",
                        folder: folder
                    )

                    var createReq = URLRequest(url: playlistsUrl)
                    createReq.httpMethod = "POST"
                    createReq.timeoutInterval = 10.0
                    headers.forEach { createReq.setValue($1, forHTTPHeaderField: $0) }
                    createReq.httpBody = try? JSONEncoder().encode(payload)

                    _ = try? await session.data(for: createReq)
                }
            }
        } catch {
            print("[NavidromeClient] Folder sync error: \(error)")
        }
    }
}
