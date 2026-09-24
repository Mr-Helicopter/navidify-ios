import SwiftUI
import NavidifyKit

public struct SearchView: View {
    @Bindable var appState = AppState.shared
    @State private var query: String = ""
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var isSearching = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Input Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.textSecondary)
                        TextField("What do you want to listen to?", text: $query)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: query) { _, newQuery in
                                performSearch(query: newQuery)
                            }

                        if !query.isEmpty {
                            Button(action: {
                                query = ""
                                songs = []
                                albums = []
                                artists = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Results
                    if isSearching {
                        ProgressView().tint(Theme.green).padding(.top, 40)
                        Spacer()
                    } else if query.isEmpty {
                        // Browse All categories placeholder
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.textSubdued)
                            Text("Find your favorite music")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("Search artists, albums, or tracks.")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Songs
                                if !songs.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Songs")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 20)

                                        ForEach(Array(songs.prefix(10).enumerated()), id: \.element.id) { index, song in
                                            SongRowView(song: song, index: index + 1) {
                                                appState.engine.playQueue(songs: songs, startIndex: index)
                                            }
                                            .padding(.horizontal, 12)
                                        }
                                    }
                                }

                                // Albums
                                if !albums.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Albums")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 20)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(albums) { album in
                                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            RemoteArtworkImage(coverArtId: album.coverArt, size: 120, cornerRadius: 6)
                                                            Text(album.displayTitle)
                                                                .font(.system(size: 12, weight: .semibold))
                                                                .foregroundColor(Theme.textPrimary)
                                                                .lineLimit(1)
                                                        }
                                                        .frame(width: 120)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }

                                // Artists
                                if !artists.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Artists")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 20)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 16) {
                                                ForEach(artists) { artist in
                                                    NavigationLink(destination: ArtistDetailView(artist: artist)) {
                                                        VStack(alignment: .center, spacing: 6) {
                                                            RemoteArtworkImage(coverArtId: artist.coverArt, size: 90, cornerRadius: 45)
                                                            Text(artist.name)
                                                                .font(.system(size: 12, weight: .medium))
                                                                .foregroundColor(Theme.textPrimary)
                                                                .lineLimit(1)
                                                        }
                                                        .frame(width: 90)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }

                                Spacer(minLength: 80)
                            }
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .navigationTitle("Search")
        }
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            songs = []
            albums = []
            artists = []
            return
        }

        isSearching = true
        Task {
            if let result = try? await appState.client.search3(query: trimmed) {
                await MainActor.run {
                    self.songs = result.songs
                    self.albums = result.albums
                    self.artists = result.artists
                    self.isSearching = false
                }
            } else {
                await MainActor.run { self.isSearching = false }
            }
        }
    }
}
