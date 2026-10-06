import XCTest
import AVFoundation
@testable import NavidifyKit

final class NavidifyKitTests: XCTestCase {
    func testSubsonicModelsAndLrcParsing() async {
        let client = NavidromeClient()
        let lrc = """
        [00:12.34]First line of lyrics
        [01:05.50]Second line of lyrics
        [02:10.00]Third line of lyrics
        """
        let parsed = await client.parseLrc(lrcText: lrc)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].text, "First line of lyrics")
        XCTAssertEqual(parsed[0].time, 12.34, accuracy: 0.01)
        XCTAssertEqual(parsed[1].time, 65.50, accuracy: 0.01)
    }

    func testKeychainHelperKeys() {
        KeychainHelper.save(key: .username, value: "testUser")
        let loaded = KeychainHelper.load(key: .username)
        XCTAssertEqual(loaded, "testUser")
        KeychainHelper.delete(key: .username)
        XCTAssertNil(KeychainHelper.load(key: .username))
    }

    func testLivePing() async {
        guard let url = ProcessInfo.processInfo.environment["NAVIDROME_BASE_URL"],
              let user = ProcessInfo.processInfo.environment["NAVIDROME_USERNAME"],
              let pass = ProcessInfo.processInfo.environment["NAVIDROME_PASSWORD"] else {
            return
        }
        let resolver = NetworkResolver()
        let ok = await resolver.pingUrl(baseUrl: url, username: user, password: pass, timeout: 5.0)
        XCTAssertTrue(ok)
    }

    func testLiveNavidromeClientFetch() async throws {
        guard let url = ProcessInfo.processInfo.environment["NAVIDROME_BASE_URL"],
              let user = ProcessInfo.processInfo.environment["NAVIDROME_USERNAME"],
              let pass = ProcessInfo.processInfo.environment["NAVIDROME_PASSWORD"] else {
            return
        }
        KeychainHelper.save(key: .tailscaleUrl, value: url)
        KeychainHelper.save(key: .username, value: user)
        KeychainHelper.save(key: .password, value: pass)

        let client = NavidromeClient()
        let albums = try await client.getAlbumList2(type: "recent", size: 2)
        print("DEBUG FETCHED ALBUMS: \(albums.map { $0.name })")
        
        do {
            let playlists = try await client.getPlaylists()
            print("DEBUG FETCHED PLAYLISTS: \(playlists.count)")
        } catch {
            print("DEBUG PLAYLISTS ERROR: \(error)")
        }

        do {
            let starred = try await client.getStarred2()
            print("DEBUG FETCHED STARRED: \(starred.songs.count)")
        } catch {
            print("DEBUG STARRED ERROR: \(error)")
        }

        do {
            let artists = try await client.getArtists()
            print("DEBUG FETCHED ARTISTS: \(artists.count)")
        } catch {
            print("DEBUG ARTISTS ERROR: \(error)")
        }

        print("DEBUG RUNNING FOLDER SYNC...")
        await client.syncFoldersToPlaylists()
        print("DEBUG FOLDER SYNC DONE")
    }

    func testLivePlayback() async throws {
        guard let url = ProcessInfo.processInfo.environment["NAVIDROME_BASE_URL"],
              let user = ProcessInfo.processInfo.environment["NAVIDROME_USERNAME"],
              let pass = ProcessInfo.processInfo.environment["NAVIDROME_PASSWORD"] else {
            return
        }
        KeychainHelper.save(key: .tailscaleUrl, value: url)
        KeychainHelper.save(key: .username, value: user)
        KeychainHelper.save(key: .password, value: pass)

        let client = NavidromeClient()
        let albums = try await client.getAlbumList2(type: "recent", size: 1)
        guard let albumId = albums.first?.id,
              let album = try await client.getAlbum(id: albumId),
              let firstSong = album.song?.first else {
            return
        }

        print("TESTING PLAYBACK OF: \(firstSong.title)")
        let engine = AudioEngine.shared
        engine.play(song: firstSong)

        for second in 1...4 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("INITIAL PLAY SECOND \(second): state=\(engine.playbackState) currentTime=\(engine.currentTime)")
        }
        XCTAssertGreaterThan(engine.currentTime, 1.5)

        print("TESTING SEEK TO 30.0s...")
        engine.seek(to: 30.0)

        for second in 1...3 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("POST-SEEK SECOND \(second): state=\(engine.playbackState) currentTime=\(engine.currentTime)")
        }
        XCTAssertGreaterThan(engine.currentTime, 31.5)

        XCTAssertEqual(engine.currentSong?.id, firstSong.id)
        engine.stop()
    }

    func testPlayQueueSelection() async throws {
        guard let url = ProcessInfo.processInfo.environment["NAVIDROME_BASE_URL"],
              let user = ProcessInfo.processInfo.environment["NAVIDROME_USERNAME"],
              let pass = ProcessInfo.processInfo.environment["NAVIDROME_PASSWORD"] else {
            return
        }
        KeychainHelper.save(key: .tailscaleUrl, value: url)
        KeychainHelper.save(key: .username, value: user)
        KeychainHelper.save(key: .password, value: pass)

        let client = NavidromeClient()
        let playlists = try await client.getPlaylists()
        guard let pl = playlists.first(where: { ($0.entry?.count ?? $0.songCount) > 2 }) ?? playlists.first else {
            print("NO PLAYLISTS FOUND")
            return
        }
        guard let detailed = try await client.getPlaylist(id: pl.id),
              let songs = detailed.entry, songs.count > 2 else {
            print("NO SONGS IN PLAYLIST \(pl.name)")
            return
        }

        print("PLAYLIST HAS \(songs.count) SONGS:")
        for (i, s) in songs.enumerated() {
            print("  [\(i)] \(s.title) (id=\(s.id), dur=\(s.duration))")
        }

        let engine = AudioEngine.shared

        // Test 1: Select song at index 2 (not index 0!)
        let targetIndex = 2
        let targetSong = songs[targetIndex]
        print("--> CALLING playQueue(songs, startIndex: \(targetIndex)) for '\(targetSong.title)'")
        engine.playQueue(songs: songs, startIndex: targetIndex)

        for second in 1...5 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("T+\(second)s: currentSong='\(engine.currentSong?.title ?? "nil")' state=\(engine.playbackState) currentTime=\(engine.currentTime) queueIndex=\(engine.queueIndex)")
        }

        XCTAssertEqual(engine.currentSong?.id, targetSong.id, "Expected song \(targetSong.title) to be playing, but \(engine.currentSong?.title ?? "nil") was playing!")

        // Test 2: While Boushret Kheir is playing, rapidly switch to track at index 7 (Lola El Banat)
        let secondTarget = songs[7]
        print("--> SWITCHING TO [7] '\(secondTarget.title)' WHILE STILL PLAYING [2]...")
        engine.playQueue(songs: songs, startIndex: 7)

        for second in 1...5 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("AFTER SWITCH T+\(second)s: currentSong='\(engine.currentSong?.title ?? "nil")' state=\(engine.playbackState) currentTime=\(engine.currentTime) queueIndex=\(engine.queueIndex)")
        }

        XCTAssertEqual(engine.currentSong?.id, secondTarget.id, "Expected \(secondTarget.title) after switch, got \(engine.currentSong?.title ?? "nil")")

        engine.stop()
    }
}
