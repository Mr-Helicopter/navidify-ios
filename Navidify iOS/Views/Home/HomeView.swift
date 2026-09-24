import SwiftUI
import NavidifyKit

public struct HomeView: View {
    @Bindable var appState = AppState.shared

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Top Greeting & Connection Badge
                        HStack {
                            Text(greetingMessage)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Theme.textPrimary)

                            Spacer()

                            Button(action: {
                                appState.showSettings = true
                            }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(connectionColor)
                                        .frame(width: 8, height: 8)
                                    Text(appState.connectionMode.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.surfaceElevated)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // Folder Playlists (Quick Access)
                        let folderPlaylists = appState.playlists.filter { $0.isSmartPlaylist }
                        if !folderPlaylists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Folder Playlists")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 20)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    ForEach(folderPlaylists.prefix(6)) { pl in
                                        NavigationLink(destination: PlaylistDetailView(playlist: pl)) {
                                            HStack(spacing: 8) {
                                                RemoteArtworkImage(coverArtId: pl.coverArt, size: 48, cornerRadius: 4)
                                                Text(pl.name)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(2)
                                                Spacer()
                                            }
                                            .background(Theme.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Recently Played / Added Albums
                        if !appState.recentAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recently Played")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(appState.recentAlbums) { album in
                                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    RemoteArtworkImage(coverArtId: album.coverArt, size: 140, cornerRadius: 6)
                                                    Text(album.displayTitle)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(Theme.textPrimary)
                                                        .lineLimit(1)
                                                    Text(album.effectiveArtist)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(Theme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 140)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Newest Albums
                        if !appState.newestAlbums.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("New Additions")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(appState.newestAlbums) { album in
                                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    RemoteArtworkImage(coverArtId: album.coverArt, size: 140, cornerRadius: 6)
                                                    Text(album.displayTitle)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(Theme.textPrimary)
                                                        .lineLimit(1)
                                                    Text(album.effectiveArtist)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(Theme.textSecondary)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 140)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        if appState.isLoadingLibrary {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(Theme.green)
                                    .padding(.top, 40)
                                Spacer()
                            }
                        } else if !appState.isConfigured {
                            VStack(spacing: 14) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.textSubdued)
                                Text("Setup Navidrome")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Enter your server URLs and credentials in Settings to start streaming.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Button("Open Settings") {
                                    appState.showSettings = true
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Theme.green)
                                .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if appState.connectionMode == .offline {
                            VStack(spacing: 14) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 44))
                                    .foregroundColor(.red.opacity(0.8))
                                Text("Server Unreachable")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Could not reach Navidrome via LAN or Tailscale.\n\n• If away from home, ensure Tailscale VPN is turned ON\n• If at home, ensure you are connected to the same Wi-Fi")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)

                                HStack(spacing: 12) {
                                    Button(action: {
                                        Task {
                                            _ = try? await appState.resolver.resolveBaseUrl(forceRecheck: true)
                                            await appState.refreshAll()
                                        }
                                    }) {
                                        Text("Retry")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 9)
                                            .background(Theme.green)
                                            .clipShape(Capsule())
                                    }

                                    Button(action: {
                                        appState.showSettings = true
                                    }) {
                                        Text("Settings")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 9)
                                            .background(Theme.surfaceElevated)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.top, 6)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if let error = appState.errorMessage, appState.recentAlbums.isEmpty && appState.playlists.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.yellow)
                                Text("Connection Issue")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                Button("Try Again") {
                                    Task {
                                        _ = try? await appState.resolver.resolveBaseUrl(forceRecheck: true)
                                        await appState.refreshAll()
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else if appState.recentAlbums.isEmpty && appState.playlists.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.textSubdued)
                                Text("No music found")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Your library appears to be empty on this server.")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }

                        Spacer(minLength: 80)
                    }
                }
                .refreshable {
                    _ = try? await appState.resolver.resolveBaseUrl(forceRecheck: true)
                    await appState.refreshAll()
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            if appState.recentAlbums.isEmpty && appState.isConfigured {
                _ = try? await appState.resolver.resolveBaseUrl(forceRecheck: true)
                await appState.refreshAll()
            }
        }
    }

    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var connectionColor: Color {
        switch appState.connectionMode {
        case .lan, .tailscale: return Theme.green
        case .reconnecting: return .yellow
        case .offline: return .red
        }
    }
}
