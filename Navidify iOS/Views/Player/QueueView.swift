import SwiftUI
import NavidifyKit

public struct QueueView: View {
    @Bindable var engine = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if engine.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textSubdued)
                        Text("Queue is empty")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    List {
                        // Now Playing Section
                        if let current = engine.currentSong {
                            Section(header: Text("Now Playing").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textSubdued)) {
                                HStack(spacing: 12) {
                                    RemoteArtworkImage(coverArtId: current.coverArt, size: 44, cornerRadius: 4)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(current.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.green)
                                            .lineLimit(1)
                                        Text(current.effectiveArtist)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "waveform")
                                        .foregroundColor(Theme.green)
                                }
                                .listRowBackground(Theme.surfaceElevated)
                            }
                        }

                        // Next in Queue Section
                        let nextSongs = Array(engine.queue.enumerated()).filter { $0.offset > engine.queueIndex }
                        if !nextSongs.isEmpty {
                            Section(header: Text("Next In Queue").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.textSubdued)) {
                                ForEach(nextSongs, id: \.element.id) { index, song in
                                    HStack(spacing: 12) {
                                        RemoteArtworkImage(coverArtId: song.coverArt, size: 44, cornerRadius: 4)
                                        VStack(alignment: .leading, spacing: 2) {
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
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        engine.playQueue(songs: engine.queue, startIndex: index)
                                    }
                                    .listRowBackground(Theme.surface)
                                }
                                .onDelete(perform: removeSongs)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.green)
                }
            }
        }
    }

    private func removeSongs(at offsets: IndexSet) {
        let nextSongsIndices = engine.queue.indices.filter { $0 > engine.queueIndex }
        for offset in offsets {
            let actualIndex = nextSongsIndices[offset]
            engine.queue.remove(at: actualIndex)
        }
    }
}
