#if canImport(ActivityKit)
import ActivityKit
import Foundation
import NavidifyKit

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<NavidifyActivityAttributes>?

    private init() {
        bindAudioEngine()
    }

    private func bindAudioEngine() {
        let engine = AudioEngine.shared

        engine.onTrackChange = { [weak self] song in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let song = song {
                    self.startOrUpdateActivity(song: song)
                } else {
                    self.endActivity()
                }
            }
        }

        engine.onStateChange = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState(state: state)
            }
        }
    }

    public func startOrUpdateActivity(song: Song) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = NavidifyActivityAttributes.ContentState(
            title: song.title,
            artist: song.effectiveArtist,
            isPlaying: AudioEngine.shared.playbackState == .playing,
            currentTime: AudioEngine.shared.currentTime,
            duration: song.duration
        )

        if let activity = currentActivity {
            Task {
                await activity.update(ActivityContent(state: contentState, staleDate: nil))
            }
        } else {
            let attributes = NavidifyActivityAttributes(songId: song.id)
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: contentState, staleDate: nil),
                    pushType: nil
                )
                self.currentActivity = activity
            } catch {
                print("[LiveActivityManager] Failed to start activity: \(error)")
            }
        }
    }

    public func updatePlaybackState(state: PlaybackState) {
        guard let activity = currentActivity, let song = AudioEngine.shared.currentSong else { return }

        let contentState = NavidifyActivityAttributes.ContentState(
            title: song.title,
            artist: song.effectiveArtist,
            isPlaying: state == .playing,
            currentTime: AudioEngine.shared.currentTime,
            duration: song.duration
        )

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    public func endActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
}
#endif
