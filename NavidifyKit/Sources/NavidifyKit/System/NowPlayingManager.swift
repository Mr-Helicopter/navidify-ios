import Foundation
@preconcurrency import MediaPlayer
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class NowPlayingManager: @unchecked Sendable {
    public static let shared = NowPlayingManager()

    private let audioEngine = AudioEngine.shared
    private var currentSong: Song?
    private static let artworkCache = NSCache<NSString, AnyObject>()
    private var lastObservedSeekTime: Double = 0.0

    private init() {
        setupRemoteCommands()
        bindAudioEngineNotifications()
    }

    private func bindAudioEngineNotifications() {
        NotificationCenter.default.addObserver(
            forName: .audioEngineTrackDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let song = notification.userInfo?["song"] as? Song
            self?.currentSong = song
            self?.updateNowPlayingInfo()
        }

        NotificationCenter.default.addObserver(
            forName: .audioEnginePlaybackStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePlaybackRate()
        }

        NotificationCenter.default.addObserver(
            forName: .audioEngineProgressDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let currentTime = notification.userInfo?["currentTime"] as? Double else { return }
            // Only update Lock Screen if there was a discontinuous jump (seek), to allow iOS interpolation
            if abs(currentTime - self.lastObservedSeekTime) > 2.0 {
                self.lastObservedSeekTime = currentTime
                self.updateElapsedPlaybackTime(currentTime: currentTime)
            } else {
                self.lastObservedSeekTime = currentTime
            }
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.audioEngine.resume()
            return .success
        }

        // Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.audioEngine.pause()
            return .success
        }

        // Toggle
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.audioEngine.togglePlayPause()
            return .success
        }

        // Next
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.audioEngine.next()
            return .success
        }

        // Previous
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.audioEngine.previous()
            return .success
        }

        // Scrubbing / Seek bar
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.audioEngine.seek(to: positionEvent.positionTime)
            return .success
        }

        // Skip 15s forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15.0]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            let target = min(self.audioEngine.duration, self.audioEngine.currentTime + 15.0)
            self.audioEngine.seek(to: target)
            return .success
        }

        // Skip 15s backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15.0]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            let target = max(0.0, self.audioEngine.currentTime - 15.0)
            self.audioEngine.seek(to: target)
            return .success
        }

        // Like / Star
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.localizedTitle = "Star"
        commandCenter.likeCommand.addTarget { [weak self] _ in
            guard let song = self?.currentSong else { return .commandFailed }
            Task {
                _ = try? await NavidromeClient.shared.star(id: song.id)
            }
            return .success
        }

        // Dislike / Unstar
        commandCenter.dislikeCommand.isEnabled = true
        commandCenter.dislikeCommand.localizedTitle = "Unstar"
        commandCenter.dislikeCommand.addTarget { [weak self] _ in
            guard let song = self?.currentSong else { return .commandFailed }
            Task {
                _ = try? await NavidromeClient.shared.unstar(id: song.id)
            }
            return .success
        }
    }

    public func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.effectiveArtist,
            MPMediaItemPropertyAlbumTitle: song.effectiveAlbum,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audioEngine.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: (audioEngine.playbackState == .playing) ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]

        if let trackNumber = song.track {
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Artwork resolution with caching
        if let coverArtId = song.coverArt {
            let cacheKey = NSString(string: coverArtId)
            #if canImport(UIKit)
            if let cachedImage = Self.artworkCache.object(forKey: cacheKey) as? UIImage {
                let artwork = MPMediaItemArtwork(boundsSize: cachedImage.size) { _ in cachedImage }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                return
            }
            #elseif canImport(AppKit)
            if let cachedImage = Self.artworkCache.object(forKey: cacheKey) as? NSImage {
                let artwork = MPMediaItemArtwork(boundsSize: cachedImage.size) { _ in cachedImage }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                return
            }
            #endif

            Task {
                if let url = await NavidromeClient.shared.getCoverArtUrl(id: coverArtId, size: 600) {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        #if canImport(UIKit)
                        if let image = UIImage(data: data) {
                            Self.artworkCache.setObject(image, forKey: cacheKey)
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                            DispatchQueue.main.async {
                                guard self.currentSong?.id == song.id else { return }
                                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                                info[MPMediaItemPropertyArtwork] = artwork
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                            }
                        }
                        #elseif canImport(AppKit)
                        if let image = NSImage(data: data) {
                            Self.artworkCache.setObject(image, forKey: cacheKey)
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                            DispatchQueue.main.async {
                                guard self.currentSong?.id == song.id else { return }
                                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                                info[MPMediaItemPropertyArtwork] = artwork
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                            }
                        }
                        #endif
                    }
                }
            }
        }
    }

    private func updatePlaybackRate() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        let isPlaying = audioEngine.playbackState == .playing
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateElapsedPlaybackTime(currentTime: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension PlaybackState: Equatable {
    public static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped), (.loading, .loading), (.playing, .playing), (.paused, .paused):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
