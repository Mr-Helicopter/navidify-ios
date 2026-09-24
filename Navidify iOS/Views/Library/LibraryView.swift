import SwiftUI
import NavidifyKit

public struct LibraryView: View {
    @Bindable var appState = AppState.shared
    @State private var selectedFilter: Filter = .all

    enum Filter: String, CaseIterable {
        case all = "All"
        case playlists = "Playlists"
        case albums = "Albums"
        case artists = "Artists"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Filter.allCases, id: \.self) { filter in
                                Button(action: {
                                    selectedFilter = filter
                                }) {
                                    Text(filter.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(selectedFilter == filter ? Theme.green : Theme.surfaceElevated)
                                        .foregroundColor(selectedFilter == filter ? .black : Theme.textPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }

                    // Content List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Liked Songs row (always present in Library)
                            if selectedFilter == .all || selectedFilter == .playlists {
                                let likedPlaylist = Playlist(
                                    id: "starred",
                                    name: "Liked Songs",
                                    comment: "Your favorite tracks",
                                    songCount: appState.starredSongs.count,
                                    duration: 0,
                                    created: nil,
                                    changed: nil,
                                    coverArt: nil,
                                    entry: appState.starredSongs
                                )
                                NavigationLink(destination: PlaylistDetailView(playlist: likedPlaylist)) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            LinearGradient(
                                                colors: [Color(red: 74/255, green: 20/255, blue: 140/255), Color(red: 18/255, green: 185/255, blue: 84/255)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            Image(systemName: "heart.fill")
                                                .foregroundColor(.white)
                                                .font(.system(size: 20))
                                        }
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Liked Songs")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Theme.textPrimary)
                                            Text("Playlist • \(appState.starredSongs.count) songs")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .buttonStyle(.plain)
                            }

                            // Playlists
                            if selectedFilter == .all || selectedFilter == .playlists {
                                ForEach(appState.playlists) { pl in
                                    NavigationLink(destination: PlaylistDetailView(playlist: pl)) {
                                        HStack(spacing: 14) {
                                            RemoteArtworkImage(coverArtId: pl.coverArt, size: 54, cornerRadius: 4)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(pl.name)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                Text(pl.isSmartPlaylist ? "Folder Playlist" : "Playlist • \(pl.songCount) songs")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(pl.isSmartPlaylist ? Theme.green : Theme.textSecondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Albums
                            if selectedFilter == .albums {
                                ForEach(appState.recentAlbums) { album in
                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        HStack(spacing: 14) {
                                            RemoteArtworkImage(coverArtId: album.coverArt, size: 54, cornerRadius: 4)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(album.displayTitle)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                Text("Album • \(album.effectiveArtist)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Artists
                            if selectedFilter == .artists {
                                ForEach(appState.artists) { artist in
                                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                        HStack(spacing: 14) {
                                            RemoteArtworkImage(coverArtId: artist.coverArt, size: 54, cornerRadius: 27)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(artist.name)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(Theme.textPrimary)
                                                    .lineLimit(1)
                                                Text("Artist")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Spacer(minLength: 80)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable {
                        _ = try? await appState.resolver.resolveBaseUrl(forceRecheck: true)
                        await appState.refreshAll()
                    }
                }
            }
            .navigationTitle("Your Library")
        }
    }
}
