//
//  NavidifyWidgetLiveActivity.swift
//  NavidifyWidget
//
//  Created by Mostafa on 24/09/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import NavidifyKit

struct NavidifyWidgetLiveActivity: Widget {
    private let accentGreen = Color(red: 0.11, green: 0.84, blue: 0.38)
    private let darkBackground = Color(red: 0.08, green: 0.08, blue: 0.10)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NavidifyActivityAttributes.self) { context in
            // Lock screen / Banner Presentation
            lockScreenView(context: context)
                .activityBackgroundTint(darkBackground.opacity(0.94))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Presentation
                DynamicIslandExpandedRegion(.leading) {
                    artworkThumbnail(path: context.state.artworkPath, size: 48, cornerRadius: 8)
                        .padding(.leading, 2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(accentGreen)
                                .frame(width: 3, height: context.state.isPlaying ? CGFloat([14, 22, 10][i]) : 4)
                        }
                    }
                    .frame(height: 24)
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(context.state.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        let progress = max(0.0, min(1.0, context.state.duration > 0 ? (context.state.currentTime / context.state.duration) : 0.0))
                        ProgressView(value: progress)
                            .tint(accentGreen)

                        HStack {
                            Text(formatTime(context.state.currentTime))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)

                            Spacer()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(accentGreen)
                                    .frame(width: 5, height: 5)
                                Text("Navidrome")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatTime(context.state.duration))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        // Playback Controls (Previous, Play/Pause, Next)
                        HStack(spacing: 40) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)

                            Button(intent: TogglePlayPauseIntent()) {
                                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 40, height: 40)
                                    .background(accentGreen)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                if let path = context.state.artworkPath, let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                        .padding(.leading, 4)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentGreen)
                        .padding(.leading, 4)
                }
            } compactTrailing: {
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(accentGreen)
                            .frame(width: 2.5, height: context.state.isPlaying ? CGFloat([9, 13, 7][i]) : 3)
                    }
                }
                .padding(.trailing, 4)
            } minimal: {
                if let path = context.state.artworkPath, let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 14, height: 14)
                        .clipShape(Circle())
                } else {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentGreen)
                }
            }
            .keylineTint(accentGreen)
        }
    }

    // MARK: - Lock Screen Banner View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<NavidifyActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Song Artwork
                artworkThumbnail(path: context.state.artworkPath, size: 56, cornerRadius: 10)

                // Track Title and Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(context.state.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    if !context.state.album.isEmpty {
                        Text(context.state.album)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.gray.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Animated waveform or status badge
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accentGreen)
                            .frame(width: 3, height: context.state.isPlaying ? CGFloat([12, 18, 9][i]) : 4)
                    }
                }
            }

            // Progress Bar
            let progress = max(0.0, min(1.0, context.state.duration > 0 ? (context.state.currentTime / context.state.duration) : 0.0))
            ProgressView(value: progress)
                .tint(accentGreen)

            HStack {
                Text(formatTime(context.state.currentTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()

                Text("Navidify")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accentGreen)

                Spacer()

                Text(formatTime(context.state.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }

            // Interactive Controls Row (Previous, Play/Pause, Next)
            HStack(spacing: 40) {
                Button(intent: PreviousTrackIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Button(intent: TogglePlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 46, height: 46)
                        .background(accentGreen)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(intent: NextTrackIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
    }

    // MARK: - Artwork Helper

    @ViewBuilder
    private func artworkThumbnail(path: String?, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let path = path, let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(white: 0.16))
                    .frame(width: size, height: size)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(accentGreen)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
