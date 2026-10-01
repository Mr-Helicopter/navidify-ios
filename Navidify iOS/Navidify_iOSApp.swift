import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif
import NavidifyKit

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(ActivityKit)
        Task {
            await LiveActivityManager.shared.cleanUpExistingActivities()
        }
        #endif
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        #if canImport(ActivityKit)
        LiveActivityManager.shared.endAllActivitiesSync()
        #endif
        AudioEngine.shared.stop()
    }
}
#endif

@main
struct Navidify_iOSApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

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
