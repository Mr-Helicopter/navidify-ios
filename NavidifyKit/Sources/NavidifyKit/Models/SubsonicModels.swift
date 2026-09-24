import Foundation

// MARK: - Subsonic Response Wrapper

public struct SubsonicResponseHeader: Codable, Sendable {
    public let status: String // "ok" or "failed"
    public let version: String?
    public let type: String?
    public let serverVersion: String?
    public let openSubsonic: Bool?
    public let error: SubsonicErrorPayload?
}

public struct SubsonicErrorPayload: Codable, Sendable {
    public let code: Int
    public let message: String
}

public struct SubsonicContainer<T: Codable & Sendable>: Codable, Sendable {
    public let subsonicResponse: T

    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

// MARK: - Data Entities

public struct Song: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let parent: String?
    public let isDir: Bool?
    public let title: String
    public let album: String?
    public let artist: String?
    public let track: Int?
    public let year: Int?
    public let genre: String?
    public let coverArt: String?
    public let size: Int?
    public let contentType: String?
    public let suffix: String?
    public let duration: Double // seconds
    public let bitRate: Int?
    public let path: String?
    public let discNumber: Int?
    public let created: String?
    public let albumId: String?
    public let artistId: String?
    public let type: String?
    public var starred: String?
    public let userRating: Int?
    public let averageRating: Double?
    public let playCount: Int?
    public let played: String?
    public let artists: [ArtistReference]?
    public let displayArtist: String?

    public init(
        id: String,
        parent: String? = nil,
        isDir: Bool? = nil,
        title: String,
        album: String? = nil,
        artist: String? = nil,
        track: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        coverArt: String? = nil,
        size: Int? = nil,
        contentType: String? = nil,
        suffix: String? = nil,
        duration: Double,
        bitRate: Int? = nil,
        path: String? = nil,
        discNumber: Int? = nil,
        created: String? = nil,
        albumId: String? = nil,
        artistId: String? = nil,
        type: String? = nil,
        starred: String? = nil,
        userRating: Int? = nil,
        averageRating: Double? = nil,
        playCount: Int? = nil,
        played: String? = nil,
        artists: [ArtistReference]? = nil,
        displayArtist: String? = nil
    ) {
        self.id = id
        self.parent = parent
        self.isDir = isDir
        self.title = title
        self.album = album
        self.artist = artist
        self.track = track
        self.year = year
        self.genre = genre
        self.coverArt = coverArt
        self.size = size
        self.contentType = contentType
        self.suffix = suffix
        self.duration = duration
        self.bitRate = bitRate
        self.path = path
        self.discNumber = discNumber
        self.created = created
        self.albumId = albumId
        self.artistId = artistId
        self.type = type
        self.starred = starred
        self.userRating = userRating
        self.averageRating = averageRating
        self.playCount = playCount
        self.played = played
        self.artists = artists
        self.displayArtist = displayArtist
    }

    public var isStarred: Bool {
        return starred != nil
    }

    public var effectiveArtist: String {
        displayArtist ?? artist ?? "Unknown Artist"
    }

    public var effectiveAlbum: String {
        album ?? "Unknown Album"
    }
}

public struct ArtistReference: Codable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Album: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let title: String?
    public let artist: String?
    public let artistId: String?
    public let coverArt: String?
    public let songCount: Int?
    public let duration: Double?
    public let created: String?
    public var starred: String?
    public let year: Int?
    public let genre: String?
    public let song: [Song]?
    public let artists: [ArtistReference]?
    public let displayArtist: String?

    public init(
        id: String,
        name: String,
        title: String? = nil,
        artist: String? = nil,
        artistId: String? = nil,
        coverArt: String? = nil,
        songCount: Int? = nil,
        duration: Double? = nil,
        created: String? = nil,
        starred: String? = nil,
        year: Int? = nil,
        genre: String? = nil,
        song: [Song]? = nil,
        artists: [ArtistReference]? = nil,
        displayArtist: String? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.coverArt = coverArt
        self.songCount = songCount
        self.duration = duration
        self.created = created
        self.starred = starred
        self.year = year
        self.genre = genre
        self.song = song
        self.artists = artists
        self.displayArtist = displayArtist
    }

    public var isStarred: Bool {
        return starred != nil
    }

    public var displayTitle: String {
        title ?? name
    }

    public var effectiveArtist: String {
        displayArtist ?? artist ?? "Unknown Artist"
    }
}

public struct Artist: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let coverArt: String?
    public let artistImageUrl: String?
    public let albumCount: Int?
    public var starred: String?
    public let album: [Album]?

    public init(
        id: String,
        name: String,
        coverArt: String? = nil,
        artistImageUrl: String? = nil,
        albumCount: Int? = nil,
        starred: String? = nil,
        album: [Album]? = nil
    ) {
        self.id = id
        self.name = name
        self.coverArt = coverArt
        self.artistImageUrl = artistImageUrl
        self.albumCount = albumCount
        self.starred = starred
        self.album = album
    }

    public var isStarred: Bool {
        return starred != nil
    }
}

public struct Playlist: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let comment: String?
    public let owner: String?
    public let `public`: Bool?
    public let songCount: Int
    public let duration: Double
    public let created: String?
    public let changed: String?
    public let coverArt: String?
    public var entry: [Song]?

    public init(
        id: String,
        name: String,
        comment: String? = nil,
        owner: String? = nil,
        public: Bool? = nil,
        songCount: Int = 0,
        duration: Double = 0,
        created: String? = nil,
        changed: String? = nil,
        coverArt: String? = nil,
        entry: [Song]? = nil
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.owner = owner
        self.public = `public`
        self.songCount = songCount
        self.duration = duration
        self.created = created
        self.changed = changed
        self.coverArt = coverArt
        self.entry = entry
    }

    public var isSmartPlaylist: Bool {
        comment?.contains("Auto-synced from folder") == true
    }
}

public struct Genre: Codable, Identifiable, Hashable, Sendable {
    public var id: String { value }
    public let value: String
    public let songCount: Int
    public let albumCount: Int

    public init(value: String, songCount: Int, albumCount: Int) {
        self.value = value
        self.songCount = songCount
        self.albumCount = albumCount
    }
}

// MARK: - Subsonic Responses

public struct PingResponse: Codable, Sendable {
    public let status: String
    public let version: String?
}

public struct AlbumList2Response: Codable, Sendable {
    public let albumList2: AlbumList2Container?
}

public struct AlbumList2Container: Codable, Sendable {
    public let album: [Album]?
}

public struct ArtistsResponse: Codable, Sendable {
    public let artists: ArtistsIndexContainer?
}

public struct ArtistsIndexContainer: Codable, Sendable {
    public let index: [ArtistIndexItem]?
}

public struct ArtistIndexItem: Codable, Sendable {
    public let name: String
    public let artist: [Artist]?
}

public struct ArtistDetailResponse: Codable, Sendable {
    public let artist: Artist?
}

public struct AlbumDetailResponse: Codable, Sendable {
    public let album: Album?
}

public struct GenresResponse: Codable, Sendable {
    public let genres: GenresContainer?
}

public struct GenresContainer: Codable, Sendable {
    public let genre: [Genre]?
}

public struct Starred2Response: Codable, Sendable {
    public let starred2: Starred2Container?
}

public struct Starred2Container: Codable, Sendable {
    public let song: [Song]?
    public let album: [Album]?
    public let artist: [Artist]?
}

public struct SearchResult3Response: Codable, Sendable {
    public let searchResult3: SearchResult3Container?
}

public struct SearchResult3Container: Codable, Sendable {
    public let song: [Song]?
    public let album: [Album]?
    public let artist: [Artist]?
}

public struct PlaylistsResponse: Codable, Sendable {
    public let playlists: PlaylistsContainer?
}

public struct PlaylistsContainer: Codable, Sendable {
    public let playlist: [Playlist]?
}

public struct PlaylistDetailResponse: Codable, Sendable {
    public let playlist: Playlist?
}

public struct LyricsResponse: Codable, Sendable {
    public let lyricsList: LyricsListContainer?
}

public struct LyricsListContainer: Codable, Sendable {
    public let structuredLyrics: [StructuredLyrics]?
}

public struct StructuredLyrics: Codable, Sendable {
    public let artist: String?
    public let title: String?
    public let synced: Bool?
    public let offset: Double?
    public let line: [StructuredLyricLine]?
}

public struct StructuredLyricLine: Codable, Sendable {
    public let start: Double? // milliseconds
    public let value: String
}

public struct PlainLyricsResponse: Codable, Sendable {
    public let lyrics: PlainLyricsContainer?
}

public struct PlainLyricsContainer: Codable, Sendable {
    public let value: String?
}

public struct ParsedLyricLine: Identifiable, Equatable, Sendable {
    public var id: Double { time }
    public let time: Double // in seconds
    public let text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

// MARK: - Native Navidrome REST Models

public struct NavidromeLoginResponse: Codable, Sendable {
    public let token: String
    public let username: String?
    public let name: String?
    public let id: String?
    public let isAdmin: Bool?
}

public struct NavidromeNativeSong: Codable, Sendable {
    public let id: String
    public let path: String?
    public let title: String?
}

public struct NavidromeNativePlaylist: Codable, Sendable {
    public let id: String
    public let name: String
    public let comment: String?
}

public struct NavidromeCreateSmartPlaylistPayload: Codable, Sendable {
    public let name: String
    public let comment: String
    public let rules: SmartPlaylistRules

    public init(name: String, comment: String, folder: String) {
        self.name = name
        self.comment = comment
        self.rules = SmartPlaylistRules(all: [SmartPlaylistRuleItem(contains: FilepathRule(filepath: folder))])
    }
}

public struct SmartPlaylistRules: Codable, Sendable {
    public let all: [SmartPlaylistRuleItem]
}

public struct SmartPlaylistRuleItem: Codable, Sendable {
    public let contains: FilepathRule
}

public struct FilepathRule: Codable, Sendable {
    public let filepath: String
}

// MARK: - Connection Mode

public enum ConnectionMode: String, CaseIterable, Sendable {
    case lan = "LAN"
    case tailscale = "Tailscale"
    case reconnecting = "Reconnecting"
    case offline = "Offline"
}
