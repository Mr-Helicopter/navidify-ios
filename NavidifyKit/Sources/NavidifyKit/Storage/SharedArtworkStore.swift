import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class SharedArtworkStore: @unchecked Sendable {
    public static let shared = SharedArtworkStore()
    public static let appGroupId = "group.Navidify.shared"

    public var sharedFolderUrl: URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId) {
            return container
        }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    public func artworkUrl(for songId: String) -> URL? {
        sharedFolderUrl?.appendingPathComponent("artwork_\(songId).jpg")
    }

    public func saveArtwork(data: Data, for songId: String) -> String? {
        guard let url = artworkUrl(for: songId) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            print("[SharedArtworkStore] Failed to write artwork file: \(error)")
            return nil
        }
    }

    public func existingArtworkPath(for songId: String) -> String? {
        guard let url = artworkUrl(for: songId) else { return nil }
        if FileManager.default.fileExists(atPath: url.path) {
            return url.path
        }
        return nil
    }
}
