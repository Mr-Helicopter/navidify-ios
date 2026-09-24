import SwiftUI
import Observation
import NavidifyKit

@Observable
public final class AppState {
    public static let shared = AppState()

    public let client = NavidromeClient.shared
    public let engine = AudioEngine.shared
    public let nowPlaying = NowPlayingManager.shared
    public let resolver = NetworkResolver.shared

    // Network & Connection
    public var connectionMode: ConnectionMode = .reconnecting
    public var resolvedUrl: String?
    public var isConfigured: Bool = false

    // Navigation & Modals
    public var selectedTab: Int = 0
    public var isNowPlayingExpanded: Bool = false
    public var showLyrics: Bool = false
    public var showQueue: Bool = false
    public var showEqualizer: Bool = false
    public var showSettings: Bool = false

    // Cached Library Data
    public var recentAlbums: [Album] = []
    public var newestAlbums: [Album] = []
    public var playlists: [Playlist] = []
    public var starredSongs: [Song] = []
    public var artists: [Artist] = []
    public var isLoadingLibrary: Bool = false
    public var errorMessage: String? = nil
    public var currentLyrics: [ParsedLyricLine] = []

    private var networkListenerId: UUID?

    private init() {
        checkConfiguration()
        setupNetworkListener()
        _ = nowPlaying // Initialize lock screen manager
    }

    public func checkConfiguration() {
        let username = KeychainHelper.load(key: .username) ?? ""
        let password = KeychainHelper.load(key: .password) ?? ""
        let lanUrl = KeychainHelper.load(key: .lanUrl) ?? ""
        let tsUrl = KeychainHelper.load(key: .tailscaleUrl) ?? ""

        self.isConfigured = !username.isEmpty && !password.isEmpty && (!lanUrl.isEmpty || !tsUrl.isEmpty)
        if !isConfigured {
            self.showSettings = true
        }
    }

    private func setupNetworkListener() {
        Task {
            await resolver.startMonitoring()
            self.networkListenerId = await resolver.addListener { [weak self] mode, url in
                Task { @MainActor [weak self] in
                    self?.connectionMode = mode
                    self?.resolvedUrl = url
                }
            }
            if isConfigured {
                _ = try? await resolver.resolveBaseUrl(forceRecheck: true)
            }
        }
    }

    public func refreshAll() async {
        guard isConfigured else { return }
        await MainActor.run {
            isLoadingLibrary = true
            errorMessage = nil
        }

        // Concurrently fetch primary library assets
        async let albumsTask = client.getAlbumList2(type: "recent", size: 12)
        async let newestTask = client.getAlbumList2(type: "newest", size: 12)
        async let playlistsTask = client.getPlaylists()
        async let starredTask = client.getStarred2()
        async let artistsTask = client.getArtists()

        do {
            let recent = try await albumsTask
            let newest = try await newestTask
            let pls = try await playlistsTask
            let starred = (try? await starredTask)?.songs ?? []
            let arts = (try? await artistsTask) ?? []

            await MainActor.run {
                self.recentAlbums = recent
                self.newestAlbums = newest
                self.playlists = pls
                self.starredSongs = starred
                self.artists = arts
                self.errorMessage = nil
                self.isLoadingLibrary = false
            }

            // Run folder sync in background decoupled from primary view rendering
            Task {
                await self.client.syncFoldersToPlaylists()
                if let updatedPlaylists = try? await self.client.getPlaylists() {
                    await MainActor.run {
                        self.playlists = updatedPlaylists
                    }
                }
            }
        } catch {
            print("[AppState] Error refreshing library: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingLibrary = false
            }
        }
    }

    public func fetchLyrics(for song: Song) async {
        let lines = await client.getLyrics(songId: song.id, artist: song.artist, title: song.title)
        await MainActor.run {
            self.currentLyrics = lines
        }
    }
}
