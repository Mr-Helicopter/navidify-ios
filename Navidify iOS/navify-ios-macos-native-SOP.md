# SOP / Build Prompt — "Navify" Native App (iOS & macOS, Swift/SwiftUI)

Paste everything below into the Xcode-capable coding agent as its initial instructions.

---

## Role & Context

You are building **Navify**, a native iOS and macOS music client that replicates Spotify's UI/UX, streaming from a self-hosted **Navidrome** server. A web version of this app (also called Navify) already exists and is fully working — this native app is **not a port of that code**, it's a fresh **Swift/SwiftUI** implementation of the same product concept, built specifically to unlock native platform integrations the web version cannot provide: **lock-screen controls, Dynamic Island, and CarPlay**. These three are the entire reason this app is being built natively instead of wrapped — do not treat them as stretch goals, they are core v1 requirements.

This is a **single-user personal tool** — no signup flow, no multi-tenant accounts. The working web app confirmed that Navidrome itself is sufficient as the identity/auth backend (a `ping.view` call against the server validates credentials directly) — no Supabase or third-party auth layer is needed here either.

Build **iOS first**, structured as a single Swift Package / Xcode project with a shared core that a macOS (Catalyst or native AppKit-adjacent SwiftUI) target can reuse — UI can diverge per-platform, but the API client, player engine, and data models should not be duplicated.

---

## 1. Backend Integration — Navidrome (Subsonic API + Navidrome Native REST)

The web app's build surfaced an important discovery — replicate it here:

- **Standard library/playback data** (artists, albums, songs, search, cover art, streaming URLs, starred items, standard playlists, scrobble) → use the **Subsonic API** (`/rest/*`), same as the web app.
- **Folder-to-playlist sync** → the web app found that mapping each physical folder in the Navidrome media library to a live playlist required going *beyond* Subsonic, using **Navidrome's native REST API** (`/api/song`, `/api/playlist`). The working approach:
  1. Query `/api/song` (authenticated with the same credentials) to enumerate root-level folders in the library.
  2. For each distinct folder, create or update a **Navidrome Smart Playlist** with the rule `{ "contains": { "filepath": folderName } }`.
  3. This makes Navidrome auto-maintain each folder as a live playlist — new files added to a folder appear in its playlist automatically, no re-sync needed beyond periodic refresh.
  4. Run this sync on app launch (and on pull-to-refresh), then load playlists normally via Subsonic's `getPlaylists`/`getPlaylist` — the sync only needs to touch the native REST endpoints, everything downstream is standard Subsonic.
- **Auth/credentials:** store `serverURL(LAN)`, `serverURL(Tailscale)`, `username`, `password` in the **iOS/macOS Keychain**, not UserDefaults or a plist — this is the native equivalent of the web app's `.env` file, but credentials must not live in plaintext on a mobile device. Provide a simple one-time settings screen to input these on first launch (this replaces the web app's build-time env vars, since native apps can't bake per-user secrets into the binary at compile time).
- **Network auto-detection:** same logic as the web app — race a `ping.view` request against the LAN URL with a short timeout (~1.5s); on failure, fall back to the Tailscale URL. Cache the resolved base URL for the session; re-resolve automatically on request failure (e.g. app backgrounded on Wi-Fi, resumed on cellular). Also re-resolve on `NWPathMonitor` network-change notifications, which the web app didn't have access to but iOS does — use it to react to network changes proactively instead of waiting for a failed request.
- **Scrobbling:** call Subsonic's `scrobble` endpoint only — a `submission=false` "now playing" ping when a track starts, and a `submission=true` scrobble at 50% played or 4 minutes (whichever first). No Last.fm or third-party scrobble target.
- Wrap everything in a dedicated `NavidromeClient` module/actor with typed `Codable` models (Artist, Album, Song, Playlist, Genre) — all other app code talks to Navidrome only through this client.

## 2. Visual Design — Spotify UI, Native Idioms

- Replicate Spotify's mobile app layout and interaction patterns (not the desktop web layout): tab bar (Home, Search, Your Library), full-screen Now Playing sheet that swipes up from a mini-player bar, swipe gestures for queue/lyrics.
- **Theme:** near-black (`#121212`) background, dark surfaces (`#181818`/`#282828`), Spotify green (`#1DB954`) accent, same typographic hierarchy as the web app for brand consistency.
- Build with **SwiftUI** throughout; use `UIViewControllerRepresentable`/`NSViewRepresentable` bridges only where a native framework (CarPlay, ActivityKit) requires it.
- Reuse the "Navify" branding, icon, and color tokens already established in the web app for visual continuity across platforms.

## 3. Core Features (parity with the web app)

- Library browsing: Home, Search, Artists/Albums/Playlists (including the auto-synced folder-playlists), Liked Songs (Subsonic star/unstar).
- Playlist create/edit/delete/reorder via Subsonic.
- Queue management: play next, add to queue, reorder, shuffle, repeat (off/all/one).
- Synced lyrics: parse `.lrc`/`getLyricsBySongId` results, scrolling karaoke-style view, matching the web app's implementation. No external lyrics API — same as web, out of scope.
- 10-band equalizer with presets, matching the band centers and presets already defined in the web app's `eqPresets`.

## 4. Native Audio Engine

Recreate the web app's dual-buffer gapless/crossfade design using native frameworks:

- Use **`AVAudioEngine`** with two `AVAudioPlayerNode`s (equivalent to the web app's dual `<audio>` elements) feeding into a shared `AVAudioUnitEQ` (10-band, matching the web app's `BiquadFilterNode` center frequencies: 31Hz–16kHz) → mixer → output.
- Preload/buffer the next track when the current one nears its end (same ~15s-remaining trigger used in the web app) and crossfade between player nodes for gapless transitions.
- Support background audio playback (`UIBackgroundModes: audio` capability) — required for lock screen controls and CarPlay to function at all.

## 5. Lock Screen Controls

- Populate **`MPNowPlayingInfoCenter`** with title, artist, album, artwork, duration, and elapsed time on every track change/seek.
- Implement **`MPRemoteCommandCenter`** handlers for play/pause, next/previous track, seek, and scrubbing, wired directly into the audio engine's transport controls.

## 6. Dynamic Island / Live Activities

- Implement a **`ActivityKit`** Live Activity showing album art, track/artist name, and a mini playback progress indicator, started when playback begins and updated on track change, ended when playback stops.
- This requires a separate **Widget Extension** target in the Xcode project (`ActivityConfiguration` + `DynamicIsland` view) — set this up early since it has its own build/signing considerations distinct from the main app target.

## 7. CarPlay

- Add a **CarPlay scene delegate** (`CPTemplateApplicationSceneDelegate`) and entitlement.
- Build the CarPlay UI using Apple's template system: `CPListTemplate` for browsing (Playlists, Albums, Artists, Liked Songs — reuse the same Navidrome data the phone app already has), and `CPNowPlayingTemplate` for playback controls, wired to the same shared audio engine and `NavidromeClient` used by the phone UI.
- CarPlay requires Apple's CarPlay entitlement (requested via Apple Developer account) before it will run on a real vehicle/simulator — flag this to the user early since it's an account-level approval step, not just code.

## 8. Deliverables

1. Xcode project (iOS target first; macOS target structured to share the core module).
2. `NavidromeClient` module covering both Subsonic and native-REST folder-sync calls.
3. Audio engine module (`AVAudioEngine` + dual player nodes + EQ + crossfade logic).
4. Widget Extension target for the Dynamic Island Live Activity.
5. CarPlay scene delegate + templates.
6. Settings screen for entering/editing server URLs and credentials, stored in Keychain.
7. README covering: required entitlements (Background Audio, CarPlay, Live Activities), Keychain usage, and how to point the app at the same Navidrome server the web app uses.

## 9. Explicitly Out of Scope

- Multi-user login/accounts or Supabase — confirmed unnecessary; Navidrome is the auth source of truth.
- Last.fm or third-party scrobbling.
- External lyrics API fallback.
- Code sharing/reuse with the existing React web app — this is an independent Swift codebase.
- Android (not requested; revisit separately if wanted later).

---

Build iteratively: scaffold the project and `NavidromeClient` (including the folder-to-playlist sync, since it's the one piece of backend logic unique to this server setup) first, then core playback with lock-screen controls, then the main SwiftUI browsing UI, then Dynamic Island, then CarPlay last since it depends on account-level entitlement approval that may take time to come through.
