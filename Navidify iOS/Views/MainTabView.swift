import SwiftUI
import NavidifyKit

public struct MainTabView: View {
    @Bindable var appState = AppState.shared

    public init() {
        // Customize UITabBar appearance for Spotify dark aesthetic
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 0.95)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                LibraryView()
                    .tabItem {
                        Label("Your Library", systemImage: "books.vertical.fill")
                    }
                    .tag(2)
            }
            .tint(.white)

            // Mini player persistent bar pinned above bottom tabs
            MiniPlayerView()
        }
        .fullScreenCover(isPresented: $appState.isNowPlayingExpanded) {
            NowPlayingView()
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
    }
}
