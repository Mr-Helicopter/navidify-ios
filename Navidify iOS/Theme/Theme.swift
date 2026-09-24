import SwiftUI

public enum Theme {
    // Spotify Dark Palette
    public static let background = Color(red: 18/255, green: 18/255, blue: 18/255) // #121212
    public static let surface = Color(red: 24/255, green: 24/255, blue: 24/255) // #181818
    public static let surfaceElevated = Color(red: 40/255, green: 40/255, blue: 40/255) // #282828
    public static let surfaceHighlight = Color(red: 56/255, green: 56/255, blue: 56/255) // #383838
    public static let green = Color(red: 29/255, green: 185/255, blue: 84/255) // #1DB954
    public static let textPrimary = Color.white
    public static let textSecondary = Color(red: 179/255, green: 179/255, blue: 179/255) // #B3B3B3
    public static let textSubdued = Color(red: 110/255, green: 110/255, blue: 110/255)

    // Corner Radius
    public static let cardRadius: CGFloat = 8
    public static let buttonRadius: CGFloat = 24
}
