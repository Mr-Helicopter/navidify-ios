#if canImport(ActivityKit)
import ActivityKit
import Foundation
import UIKit
import NavidifyKit

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<NavidifyActivityAttributes>?
    private var lastProgressUpdateTime: Date = .distantPast
    private var currentArtworkPath: String?

    private init() {
        bindAudioEngineNotifications()
    }

    private func bindAudioEngineNotifications() {
        NotificationCenter.default.addObserver(
            forName: .audioEngineTrackDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let song = notification.userInfo?["song"] as? Song
            if let song = song {
                self?.startOrUpdateActivity(song: song)
            } else {
                self?.endActivity()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .audioEnginePlaybackStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let state = notification.userInfo?["playbackState"] as? PlaybackState {
                if case .stopped = state {
                    self.endActivity()
                } else {
                    self.updatePlaybackState(state: state)
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .audioEngineProgressDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let currentTime = notification.userInfo?["currentTime"] as? Double,
                  let duration = notification.userInfo?["duration"] as? Double else { return }
            self.throttledProgressUpdate(currentTime: currentTime, duration: duration)
        }

        // Clean up immediately if app process is terminated from recents
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endAllActivitiesSync()
        }
    }

    public func cleanUpExistingActivities() async {
        let existing = Activity<NavidifyActivityAttributes>.activities
        guard !existing.isEmpty else { return }
        for activity in existing {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.currentActivity = nil
        self.currentArtworkPath = nil
    }

    public func startOrUpdateActivity(song: Song) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let existingArtwork = SharedArtworkStore.shared.existingArtworkPath(for: song.id)
        self.currentArtworkPath = existingArtwork

        let contentState = NavidifyActivityAttributes.ContentState(
            title: song.title,
            artist: song.effectiveArtist,
            album: song.effectiveAlbum,
            isPlaying: AudioEngine.shared.playbackState == .playing,
            currentTime: AudioEngine.shared.currentTime,
            duration: song.duration,
            artworkPath: existingArtwork
        )

        // Reuse an existing activity if already present, or clean up any extra duplicates
        let allActivities = Activity<NavidifyActivityAttributes>.activities
        let activityToUse = currentActivity ?? allActivities.first

        if allActivities.count > 1 {
            for extra in allActivities where extra.id != activityToUse?.id {
                Task.detached(priority: .background) {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
            }
        }

        if let activity = activityToUse {
            self.currentActivity = activity
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

        // Fetch artwork if not already cached
        if existingArtwork == nil, let coverArtId = song.coverArt {
            Task {
                if let url = await NavidromeClient.shared.getCoverArtUrl(id: coverArtId, size: 300) {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        if let path = SharedArtworkStore.shared.saveArtwork(data: data, for: song.id) {
                            await MainActor.run {
                                guard AudioEngine.shared.currentSong?.id == song.id else { return }
                                self.currentArtworkPath = path
                                self.pushContentState(artworkPath: path)
                            }
                        }
                    }
                }
            }
        }
    }

    public func updatePlaybackState(state: PlaybackState) {
        pushContentState(isPlaying: state == .playing)
    }

    private func throttledProgressUpdate(currentTime: Double, duration: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastProgressUpdateTime) >= 2.0 else { return }
        lastProgressUpdateTime = now
        pushContentState(currentTime: currentTime, duration: duration)
    }

    private func pushContentState(
        isPlaying: Bool? = nil,
        currentTime: Double? = nil,
        duration: Double? = nil,
        artworkPath: String? = nil
    ) {
        guard let activity = currentActivity, let song = AudioEngine.shared.currentSong else { return }

        let state = NavidifyActivityAttributes.ContentState(
            title: song.title,
            artist: song.effectiveArtist,
            album: song.effectiveAlbum,
            isPlaying: isPlaying ?? (AudioEngine.shared.playbackState == .playing),
            currentTime: currentTime ?? AudioEngine.shared.currentTime,
            duration: duration ?? song.duration,
            artworkPath: artworkPath ?? self.currentArtworkPath
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    public func endActivity() {
        let activities = Activity<NavidifyActivityAttributes>.activities
        guard !activities.isEmpty else {
            self.currentActivity = nil
            self.currentArtworkPath = nil
            return
        }
        Task.detached(priority: .userInitiated) {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            await MainActor.run {
                LiveActivityManager.shared.currentActivity = nil
                LiveActivityManager.shared.currentArtworkPath = nil
            }
        }
    }

    public func endAllActivitiesSync() {
        let activities = Activity<NavidifyActivityAttributes>.activities
        guard !activities.isEmpty else {
            self.currentActivity = nil
            self.currentArtworkPath = nil
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        let bgTask = UIApplication.shared.beginBackgroundTask {
            semaphore.signal()
        }

        Task.detached(priority: .userInitiated) {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            UIApplication.shared.endBackgroundTask(bgTask)
            semaphore.signal()
        }

        // Wait up to 1.5s for ActivityKit IPC daemon to dismiss live activity before process termination
        _ = semaphore.wait(timeout: .now() + 1.5)
        self.currentActivity = nil
        self.currentArtworkPath = nil
    }
}
#endif
