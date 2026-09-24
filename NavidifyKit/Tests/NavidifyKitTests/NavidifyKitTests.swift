import XCTest
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

        // Wait 3.5 seconds for stream spooling, buffer schedule, and engine.play()
        try await Task.sleep(nanoseconds: 3_500_000_000)

        print("PLAYBACK STATE: \(engine.playbackState)")
        print("CURRENT TIME: \(engine.currentTime)")
        XCTAssertEqual(engine.currentSong?.id, firstSong.id)
        engine.stop()
    }
}
