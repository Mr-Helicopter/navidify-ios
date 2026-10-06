import SwiftUI
import NavidifyKit

public struct PlaylistDetailView: View {
    let playlist: Playlist
    @Bindable var appState = AppState.shared
    @State private var songs: [Song] = []
    @State private var isLoading = true

    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Artwork & Title
                    HStack(spacing: 16) {
                        RemoteArtworkImage(coverArtId: playlist.coverArt ?? songs.first?.coverArt, size: 120, cornerRadius: 8)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                        VStack(alignment: .leading, spacing: 6) {
                            if playlist.isSmartPlaylist {
                                Text("FOLDER PLAYLIST")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.green)
                            }
                            Text(playlist.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(2)

                            if let comment = playlist.comment, !comment.isEmpty {
                                Text(comment)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                            }

                            Text("\(songs.count) songs")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSubdued)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Play All button
                    if !songs.isEmpty {
                        HStack {
                            Button(action: {
                                appState.engine.playQueue(songs: songs, startIndex: 0)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.green)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                            }

                            Button(action: {
                                appState.engine.isShuffle = true
                                let shuffled = songs.shuffled()
                                appState.engine.playQueue(songs: shuffled, startIndex: 0)
                            }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(width: 44, height: 44)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Songs List
                    if isLoading {
                        ProgressView().tint(Theme.green).frame(maxWidth: .infinity).padding(.top, 40)
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
            await loadSongs()
        }
    }

    private func loadSongs() async {
        // If playlist already has entry items (e.g. Liked Songs passed from LibraryView), use them directly
        if let existingEntries = playlist.entry, !existingEntries.isEmpty {
            await MainActor.run {
                self.songs = existingEntries
                self.isLoading = false
            }
            return
        }

        if playlist.id == "starred" {
            if let res = try? await appState.client.getStarred2() {
                await MainActor.run {
                    self.songs = res.songs
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
            return
        }

        if let detailed = try? await appState.client.getPlaylist(id: playlist.id),
           let entries = detailed.entry {
            await MainActor.run {
                self.songs = entries
                self.isLoading = false
            }
        } else {
            await MainActor.run { self.isLoading = false }
        }
    }
}

public struct SongRowView: View {
    let song: Song
    let index: Int
    let onSelect: () -> Void

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                RemoteArtworkImage(coverArtId: song.coverArt, size: 44, cornerRadius: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(song.effectiveArtist)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(formatDuration(song.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textSubdued)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ dur: Double) -> String {
        let s = Int(dur)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
