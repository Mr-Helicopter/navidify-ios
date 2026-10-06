import SwiftUI

public struct SpotifyLogoView: View {
    public var size: CGFloat
    public var showText: Bool

    public init(size: CGFloat = 28, showText: Bool = false) {
        self.size = size
        self.showText = showText
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image("SpotifyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)

            if showText {
                Text("Spotify")
                    .font(.system(size: size * 0.75, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            SpotifyLogoView(size: 32)
            SpotifyLogoView(size: 40, showText: true)
        }
    }
}
