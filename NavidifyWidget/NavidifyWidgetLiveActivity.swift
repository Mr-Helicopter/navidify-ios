//
//  NavidifyWidgetLiveActivity.swift
//  NavidifyWidget
//
//  Created by Mostafa on 24/09/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI
import NavidifyKit

struct NavidifyWidgetLiveActivity: Widget {
    private let accentGreen = Color(red: 0.11, green: 0.84, blue: 0.38)
    private let darkBackground = Color(red: 0.08, green: 0.08, blue: 0.10)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NavidifyActivityAttributes.self) { context in
            // Lock screen / Banner Presentation
            lockScreenView(context: context)
                .activityBackgroundTint(darkBackground.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Presentation
                DynamicIslandExpandedRegion(.leading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(white: 0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(accentGreen)
                    }
                    .padding(.leading, 4)
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
                    .padding(.trailing, 6)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(context.state.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Progress bar
                        let progress = max(0.0, min(1.0, context.state.duration > 0 ? (context.state.currentTime / context.state.duration) : 0.0))
                        ProgressView(value: progress)
                            .tint(accentGreen)
                            .scaleEffect(x: 1, y: 0.8, anchor: .center)

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
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentGreen)
                }
                .padding(.leading, 4)
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
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentGreen)
            }
            .keylineTint(accentGreen)
        }
    }

    // MARK: - Lock Screen Banner View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<NavidifyActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            // Artwork placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(accentGreen)
            }

            // Song Info & Progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.state.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(context.state.artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentGreen)
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
            }
        }
        .padding(14)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
