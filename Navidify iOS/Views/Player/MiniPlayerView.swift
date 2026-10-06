import SwiftUI
import NavidifyKit

public struct MiniPlayerView: View {
    @Bindable var appState = AppState.shared

    public var body: some View {
        if let currentSong = appState.engine.currentSong {
            VStack(spacing: 0) {
                // Mini Progress line on top
                GeometryReader { geo in
                    let progress = appState.engine.duration > 0
                        ? min(1.0, max(0.0, appState.engine.currentTime / appState.engine.duration))
                        : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 2)
                        Rectangle()
                            .fill(Theme.green)
                            .frame(width: geo.size.width * CGFloat(progress), height: 2)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    RemoteArtworkImage(coverArtId: currentSong.coverArt, size: 40, cornerRadius: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentSong.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Text(currentSong.effectiveArtist)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Play/Pause button
                    Button(action: {
                        appState.engine.togglePlayPause()
                    }) {
                        Image(systemName: appState.engine.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    // Next track button
                    Button(action: {
                        appState.engine.next()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 56)
                .background(Theme.surfaceElevated)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                appState.isNowPlayingExpanded = true
            }
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 8)
            .padding(.bottom, 56) // float cleanly above bottom tab bar without intercepting tab touches
        }
    }
}
