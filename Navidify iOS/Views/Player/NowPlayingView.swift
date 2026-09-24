import SwiftUI
import NavidifyKit

public struct NowPlayingView: View {
    @Bindable var appState = AppState.shared
    @Bindable var engine = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isDraggingScrubber = false
    @State private var scrubTime: Double = 0.0

    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let song = engine.currentSong {
                VStack(spacing: 24) {
                    // Top Bar (Dismiss chevron, Title, Context menu)
                    HStack {
                        Button(action: {
                            appState.isNowPlayingExpanded = false
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }

                        Spacer()

                        VStack(spacing: 2) {
                            Text("PLAYING FROM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSubdued)
                            Text(song.effectiveAlbum)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: {
                            appState.showEqualizer = true
                        }) {
                            Image(systemName: "slider.vertical.3")
                                .font(.system(size: 18))
                                .foregroundColor(engine.isEQEnabled ? Theme.green : Theme.textPrimary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Spacer(minLength: 8)

                    // Large Album Artwork
                    GeometryReader { geo in
                        let side = min(geo.size.width - 48, geo.size.height)
                        RemoteArtworkImage(coverArtId: song.coverArt, size: Int(side), cornerRadius: 8)
                            .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: 340)

                    Spacer(minLength: 8)

                    // Track & Artist Title + Star / Like Button
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Text(song.effectiveArtist)
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: {
                            toggleStar(for: song)
                        }) {
                            Image(systemName: song.isStarred ? "heart.fill" : "heart")
                                .font(.system(size: 22))
                                .foregroundColor(song.isStarred ? Theme.green : Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Scrubber Bar
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { isDraggingScrubber ? scrubTime : engine.currentTime },
                                set: { newValue in
                                    isDraggingScrubber = true
                                    scrubTime = newValue
                                }
                            ),
                            in: 0...max(1.0, engine.duration),
                            onEditingChanged: { editing in
                                if !editing {
                                    engine.seek(to: scrubTime)
                                    isDraggingScrubber = false
                                }
                            }
                        )
                        .tint(Theme.textPrimary)

                        HStack {
                            Text(formatTime(isDraggingScrubber ? scrubTime : engine.currentTime))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSubdued)
                            Spacer()
                            Text(formatTime(engine.duration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSubdued)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Main Transport Controls
                    HStack(spacing: 36) {
                        // Shuffle
                        Button(action: {
                            engine.isShuffle.toggle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 20))
                                .foregroundColor(engine.isShuffle ? Theme.green : Theme.textSecondary)
                        }

                        // Previous
                        Button(action: {
                            engine.previous()
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.textPrimary)
                        }

                        // Play / Pause Circle
                        Button(action: {
                            engine.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.textPrimary)
                                    .frame(width: 64, height: 64)
                                Image(systemName: engine.playbackState == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.black)
                                    .offset(x: engine.playbackState == .playing ? 0 : 2)
                            }
                        }

                        // Next
                        Button(action: {
                            engine.next()
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Theme.textPrimary)
                        }

                        // Repeat
                        Button(action: {
                            cycleRepeatMode()
                        }) {
                            Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 20))
                                .foregroundColor(engine.repeatMode != .off ? Theme.green : Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Bottom Sheet Actions (Queue & Lyrics)
                    HStack {
                        Button(action: {
                            appState.showLyrics = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.system(size: 14))
                                Text("Lyrics")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.surfaceElevated)
                            .foregroundColor(Theme.textPrimary)
                            .clipShape(Capsule())
                        }

                        Spacer()

                        Button(action: {
                            appState.showQueue = true
                        }) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.textSecondary)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $appState.showLyrics) {
            if let song = engine.currentSong {
                LyricsView(song: song)
            }
        }
        .sheet(isPresented: $appState.showQueue) {
            QueueView()
        }
        .sheet(isPresented: $appState.showEqualizer) {
            EqualizerView()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func cycleRepeatMode() {
        switch engine.repeatMode {
        case .off: engine.repeatMode = .all
        case .all: engine.repeatMode = .one
        case .one: engine.repeatMode = .off
        }
    }

    private func toggleStar(for song: Song) {
        Task {
            if song.isStarred {
                try? await appState.client.unstar(id: song.id, type: "song")
            } else {
                try? await appState.client.star(id: song.id, type: "song")
            }
            // Update local starred state
            await MainActor.run {
                if let idx = engine.queue.firstIndex(where: { $0.id == song.id }) {
                    engine.queue[idx].starred = song.isStarred ? nil : "now"
                }
            }
        }
    }
}
