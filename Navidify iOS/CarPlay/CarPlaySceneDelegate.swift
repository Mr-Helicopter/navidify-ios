#if canImport(CarPlay)
import CarPlay
import NavidifyKit

public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let rootTemplate = createRootTabBarTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: true, completion: nil)
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    private func createRootTabBarTemplate() -> CPTabBarTemplate {
        // Tab 1: Playlists / Folders
        let playlistsTemplate = CPListTemplate(title: "Playlists", sections: [
            CPListSection(items: [
                CPListItem(text: "Loading Playlists...", detailText: "Connecting to Navidrome")
            ])
        ])
        playlistsTemplate.tabImage = UIImage(systemName: "music.note.list")

        // Tab 2: Liked Songs
        let likedTemplate = CPListTemplate(title: "Liked Songs", sections: [
            CPListSection(items: [
                CPListItem(text: "Liked Songs", detailText: "Favorites from Navidrome")
            ])
        ])
        likedTemplate.tabImage = UIImage(systemName: "heart.fill")

        // Tab 3: Now Playing
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        nowPlayingTemplate.tabImage = UIImage(systemName: "play.circle.fill")

        let tabBar = CPTabBarTemplate(templates: [playlistsTemplate, likedTemplate, nowPlayingTemplate])

        Task {
            await populatePlaylists(template: playlistsTemplate)
        }

        return tabBar
    }

    private func populatePlaylists(template: CPListTemplate) async {
        let pls = (try? await NavidromeClient.shared.getPlaylists()) ?? []
        let items: [CPListItem] = pls.map { pl in
            let item = CPListItem(text: pl.name, detailText: pl.isSmartPlaylist ? "Folder Playlist" : "\(pl.songCount) tracks")
            item.handler = { [weak self] _, completion in
                Task {
                    if let detailed = try? await NavidromeClient.shared.getPlaylist(id: pl.id),
                       let entries = detailed.entry, !entries.isEmpty {
                        AudioEngine.shared.playQueue(songs: entries, startIndex: 0)
                        self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                    }
                    completion()
                }
            }
            return item
        }

        if !items.isEmpty {
            let section = CPListSection(items: items)
            template.updateSections([section])
        }
    }
}
#endif
