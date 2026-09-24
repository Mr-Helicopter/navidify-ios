import SwiftUI

@main
struct Navidify_iOSApp: App {
    init() {
        #if canImport(ActivityKit)
        _ = LiveActivityManager.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}
