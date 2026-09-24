# Navidify Native (iOS & macOS)

Navidify is a native iOS client for self-hosted [Navidrome](https://www.navidrome.org/) music servers, replicating Spotify's mobile UI and UX.

It is built from the ground up in Swift / SwiftUI to deliver core system-level audio integrations:
- **Lock Screen & Control Center controls** (`MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`) with high-resolution artwork and scrubbing.
- **Dynamic Island & Live Activities** (`ActivityKit`).
- **CarPlay** (`CPTemplateApplicationSceneDelegate`, `CPListTemplate`, `CPNowPlayingTemplate`).
- **10-Band Parametric Equalizer** with web app presets (`AVAudioUnitEQ`).
- **LAN & Tailscale auto-detection** (`NWPathMonitor` with quick 1.5s LAN race and automatic failover).
- **Native Navidrome Folder-to-Smart-Playlist sync** via Navidrome's native REST endpoints.
- **Keychain storage** for server credentials.

---

## Architecture

The project is structured around a shared core package:

```
Navidify iOS/
├── NavidifyKit/                     # Shared Swift Package (iOS 17+ & macOS 14+)
│   ├── Sources/NavidifyKit/
│   │   ├── Models/                 # Codable Subsonic & Navidrome models
│   │   ├── Storage/                # KeychainHelper for secure credentials
│   │   ├── Network/                # NetworkResolver (NWPathMonitor, LAN/Tailscale ping race)
│   │   ├── Client/                 # NavidromeClient (Subsonic API + Native REST folder sync)
│   │   ├── Audio/                  # AudioEngine (AVAudioEngine, 10-band EQ, streaming buffer)
│   │   └── System/                 # NowPlayingManager (MPNowPlayingInfoCenter & Remote commands)
│   └── Tests/                      # Unit tests for parser and keychain
│
└── Navidify iOS/                   # Native iOS Application
    ├── Theme/                      # Spotify dark palette (#121212, #1DB954)
    ├── State/                      # AppState observable container
    ├── Views/
    │   ├── MainTabView.swift       # Tab bar (Home, Search, Your Library) + MiniPlayer
    │   ├── Home/                   # Greetings, Folder Playlists, Recent & New Additions
    │   ├── Search/                 # Real-time search across tracks, albums, artists
    │   ├── Library/                # Filter chips, Liked songs, Playlists, Albums, Artists
    │   ├── Player/                 # MiniPlayer, NowPlayingView, Lyrics, Queue, Equalizer
    │   ├── Detail/                 # AlbumDetailView, ArtistDetailView, PlaylistDetailView
    │   └── Settings/               # Server configuration (LAN / Tailscale / Credentials)
    ├── CarPlay/                    # CarPlaySceneDelegate template integration
    └── LiveActivity/               # ActivityKit Dynamic Island & Lock Screen attributes
```

---

## Configuration & First Launch

1. Open `Navidify iOS.xcodeproj` in Xcode.
2. Build and run on an iOS Simulator or connected iPhone (iOS 17.0+).
3. On first launch, the **Server Settings** modal will automatically appear (or tap the status badge on the Home tab).
4. Enter:
   - **LAN Server URL**: e.g., `http://192.168.1.100:4533`
   - **Tailscale Server URL**: e.g., `http://my-navidrome.tailscale.net:4533`
   - **Username**: Your Navidrome username
   - **Password**: Your Navidrome password
5. Tap **Test Connection** to verify ping times against both endpoints.
6. Tap **Save & Connect**. Credentials are automatically encrypted and stored in the **iOS Keychain**.

---

## Entitlements & Background Audio

The following entitlements and configurations are enabled in the project:
- `UIBackgroundModes: audio`: Configured in build settings (`INFOPLIST_KEY_UIBackgroundModes = audio`) to keep audio playing and receiving remote controls when the screen locks.
- `NSAllowsArbitraryLoads`: Configured to permit plain HTTP LAN/Tailscale connections.
- `CarPlay`: CarPlay scene delegate is wired up. Running CarPlay in a real vehicle requires the CarPlay entitlement from your Apple Developer account.
