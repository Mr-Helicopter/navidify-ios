import SwiftUI
import NavidifyKit

public struct AlbumDetailView: View {
    let album: Album
    @Bindable var appState = AppState.shared
    @State private var songs: [Song] = []
    @State private var isLoading = true

    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Album Artwork
                    HStack {
                        Spacer()
                        RemoteArtworkImage(coverArtId: album.coverArt, size: 200, cornerRadius: 8)
                            .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 8)
                        Spacer()
                    }
                    .padding(.top, 16)

                    // Title & Artist
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.displayTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                        Text(album.effectiveArtist)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: 8) {
                            if let year = album.year {
                                Text(String(year))
                            }
                            if let count = album.songCount {
                                Text("• \(count) songs")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSubdued)
                    }
                    .padding(.horizontal, 20)

                    // Transport Actions
                    if !songs.isEmpty {
                        HStack(spacing: 16) {
                            Button(action: {
                                appState.engine.playQueue(songs: songs, startIndex: 0)
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Theme.green)
                            }

                            Button(action: {
                                appState.engine.isShuffle = true
                                let shuffled = songs.shuffled()
                                appState.engine.playQueue(songs: shuffled, startIndex: 0)
                            }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 22))
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Songs
                    if isLoading {
                        ProgressView().tint(Theme.green).frame(maxWidth: .infinity).padding(.top, 30)
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                                SongRowView(song: song, index: index + 1) {
                                    if let targetIdx = songs.firstIndex(where: { $0.id == song.id }) {
                                        appState.engine.playQueue(songs: songs, startIndex: targetIdx)
                                    } else {
                                        appState.engine.playQueue(songs: songs, startIndex: index)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbum()
        }
    }

    private func loadAlbum() async {
        if let detailed = try? await appState.client.getAlbum(id: album.id),
           let entries = detailed.song {
            await MainActor.run {
                self.songs = entries
                self.isLoading = false
            }
        } else {
            await MainActor.run { self.isLoading = false }
        }
    }
}
