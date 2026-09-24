#if os(iOS)
import AppIntents
import Foundation

public struct TogglePlayPauseIntent: AudioPlaybackIntent {
    public static var title: LocalizedStringResource = "Toggle Play / Pause"
    public static var description = IntentDescription("Toggles playback between play and pause")

    public init() {}

    public func perform() async throws -> some IntentResult {
        AudioEngine.shared.togglePlayPause()
        return .result()
    }
}

public struct NextTrackIntent: AudioPlaybackIntent {
    public static var title: LocalizedStringResource = "Next Track"
    public static var description = IntentDescription("Skips to the next track")

    public init() {}

    public func perform() async throws -> some IntentResult {
        AudioEngine.shared.next()
        return .result()
    }
}

public struct PreviousTrackIntent: AudioPlaybackIntent {
    public static var title: LocalizedStringResource = "Previous Track"
    public static var description = IntentDescription("Plays the previous track")

    public init() {}

    public func perform() async throws -> some IntentResult {
        AudioEngine.shared.previous()
        return .result()
    }
}
#endif
