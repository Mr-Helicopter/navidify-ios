import SwiftUI
import NavidifyKit

public struct SettingsView: View {
    @Bindable var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss

    @State private var lanUrl: String = ""
    @State private var tailscaleUrl: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSaving: Bool = false
    @State private var testStatus: String?
    @State private var isTesting: Bool = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Form {
                    Section(header: Text("CONNECTION STATUS").foregroundColor(Theme.textSubdued)) {
                        HStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                            Text(appState.connectionMode.rawValue)
                                .foregroundColor(Theme.textPrimary)
                                .font(.system(size: 14, weight: .semibold))

                            Spacer()

                            if let url = appState.resolvedUrl {
                                Text(url)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .listRowBackground(Theme.surfaceElevated)
                    }

                    Section(
                        header: Text("NAVIDROME SERVERS").foregroundColor(Theme.textSubdued),
                        footer: Text("Navidify tests the LAN server first (1.5s timeout) and automatically falls back to your Tailscale server when outside your home network.").foregroundColor(Theme.textSubdued)
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LAN Server URL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                            TextField("http://192.168.1.x:4533", text: $lanUrl)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surfaceElevated)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tailscale Server URL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                            TextField("http://your-node.tailscale.net:4533", text: $tailscaleUrl)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surfaceElevated)
                    }

                    Section(header: Text("CREDENTIALS (KEYCHAIN SECURED)").foregroundColor(Theme.textSubdued)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                            TextField("Navidrome Username", text: $username)
                                .textContentType(.username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surfaceElevated)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                            SecureField("Navidrome Password", text: $password)
                                .textContentType(.password)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surfaceElevated)
                    }

                    Section {
                        Button(action: testConnection) {
                            HStack {
                                Spacer()
                                if isTesting {
                                    ProgressView()
                                        .tint(Theme.green)
                                } else {
                                    Text("Test Connection")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.green)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Theme.surfaceElevated)

                        if let status = testStatus {
                            Text(status)
                                .font(.system(size: 13))
                                .foregroundColor(status.contains("Success") ? Theme.green : .red)
                                .listRowBackground(Theme.surfaceElevated)
                        }
                    }

                    Section {
                        Button(action: saveSettings) {
                            HStack {
                                Spacer()
                                Text("Save & Connect")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.green)
                    }

                    Section(header: Text("ABOUT").foregroundColor(Theme.textSubdued)) {
                        HStack(spacing: 12) {
                            SpotifyLogoView(size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Navidify")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Spotify Experience for Navidrome")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Theme.surfaceElevated)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.green)
                }
            }
        }
        .onAppear(perform: loadSettings)
    }

    private var statusColor: Color {
        switch appState.connectionMode {
        case .lan, .tailscale: return Theme.green
        case .reconnecting: return .yellow
        case .offline: return .red
        }
    }

    private func loadSettings() {
        lanUrl = KeychainHelper.load(key: .lanUrl) ?? ""
        tailscaleUrl = KeychainHelper.load(key: .tailscaleUrl) ?? ""
        username = KeychainHelper.load(key: .username) ?? ""
        password = KeychainHelper.load(key: .password) ?? ""
    }

    private func saveSettings() {
        KeychainHelper.save(key: .lanUrl, value: lanUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        KeychainHelper.save(key: .tailscaleUrl, value: tailscaleUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        KeychainHelper.save(key: .username, value: username.trimmingCharacters(in: .whitespacesAndNewlines))
        KeychainHelper.save(key: .password, value: password.trimmingCharacters(in: .whitespacesAndNewlines))

        appState.checkConfiguration()
        dismiss()

        Task {
            _ = try? await appState.resolver.resolveBaseUrl(forceRecheck: true)
            await appState.refreshAll()
        }
    }

    private func testConnection() {
        isTesting = true
        testStatus = nil

        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let lan = lanUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let ts = tailscaleUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !u.isEmpty, !p.isEmpty else {
            isTesting = false
            testStatus = "Please enter username and password."
            return
        }

        Task {
            async let lanTest: String? = {
                guard !lan.isEmpty else { return nil }
                let ok = await appState.resolver.pingUrl(baseUrl: lan, username: u, password: p, timeout: 2.0)
                return "LAN: \(ok ? "Connected ✅" : "Unreachable ❌")"
            }()

            async let tsTest: String? = {
                guard !ts.isEmpty else { return nil }
                let ok = await appState.resolver.pingUrl(baseUrl: ts, username: u, password: p, timeout: 4.0)
                return "Tailscale: \(ok ? "Connected ✅" : "Unreachable ❌")"
            }()

            let (lanResult, tsResult) = await (lanTest, tsTest)
            let combined = [lanResult, tsResult].compactMap { $0 }

            await MainActor.run {
                self.isTesting = false
                if combined.isEmpty {
                    self.testStatus = "Please enter a server URL."
                } else {
                    self.testStatus = combined.joined(separator: "\n")
                }
            }
        }
    }
}
