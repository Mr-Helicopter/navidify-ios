import SwiftUI
import NavidifyKit

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 1024 * 1024 * 80 // 80 MB
    }

    func get(key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(key: String, image: UIImage) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

public struct RemoteArtworkImage: View {
    let coverArtId: String?
    let size: Int
    let cornerRadius: CGFloat

    @State private var imageUrl: URL?
    @State private var uiImage: UIImage?

    public init(coverArtId: String?, size: Int = 300, cornerRadius: CGFloat = 4) {
        self.coverArtId = coverArtId
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.surfaceElevated)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: CGFloat(size) * 0.25))
                            .foregroundColor(Theme.textSubdued)
                    )
            }
        }
        .frame(width: CGFloat(size), height: CGFloat(size))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: coverArtId) {
            guard let id = coverArtId, !id.isEmpty else { return }
            let cacheKey = "\(id)_\(size)"
            if let cached = ImageCache.shared.get(key: cacheKey) {
                self.uiImage = cached
                return
            }
            if let url = await NavidromeClient.shared.getCoverArtUrl(id: id, size: size) {
                self.imageUrl = url
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    ImageCache.shared.set(key: cacheKey, image: img)
                    await MainActor.run {
                        self.uiImage = img
                    }
                }
            }
        }
    }
}
