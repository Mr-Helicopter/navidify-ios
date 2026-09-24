#if canImport(ActivityKit)
import ActivityKit
import Foundation

public struct NavidifyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var artist: String
        public var isPlaying: Bool
        public var currentTime: Double
        public var duration: Double

        public init(title: String, artist: String, isPlaying: Bool, currentTime: Double, duration: Double) {
            self.title = title
            self.artist = artist
            self.isPlaying = isPlaying
            self.currentTime = currentTime
            self.duration = duration
        }
    }

    public var songId: String

    public init(songId: String) {
        self.songId = songId
    }
}
#endif
