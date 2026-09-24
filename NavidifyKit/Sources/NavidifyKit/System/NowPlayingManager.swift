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

    private init() {
        setupRemoteCommands()
        bindAudioEngine()
    }

    private func bindAudioEngine() {
        audioEngine.onTrackChange = { [weak self] song in
            self?.currentSong = song
            self?.updateNowPlayingInfo()
        }

        audioEngine.onStateChange = { [weak self] _ in
            self?.updatePlaybackRate()
        }

        audioEngine.onProgressUpdate = { [weak self] currentTime, duration in
            self?.updateProgress(currentTime: currentTime, duration: duration)
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.audioEngine.resume()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.audioEngine.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.audioEngine.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.audioEngine.next()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.audioEngine.previous()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.audioEngine.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    public func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.effectiveArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.effectiveAlbum
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = (audioEngine.playbackState == .playing) ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Fetch cover art asynchronously and attach to Lock Screen artwork
        if let coverArtId = song.coverArt {
            Task {
                if let url = await NavidromeClient.shared.getCoverArtUrl(id: coverArtId, size: 600) {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        #if canImport(UIKit)
                        if let image = UIImage(data: data) {
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                            DispatchQueue.main.async {
                                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                                info[MPMediaItemPropertyArtwork] = artwork
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                            }
                        }
                        #elseif canImport(AppKit)
                        if let image = NSImage(data: data) {
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                            DispatchQueue.main.async {
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

    private func updateProgress(currentTime: Double, duration: Double) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
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
