import Foundation
import MusicKit

protocol MusicService {
    func fetchSongs() async throws -> MusicItemCollection<Song>
    func fetchLibraryPlaylists() async throws -> MusicItemCollection<Playlist>
    func fetchCatalogPlaylistTracks(searchTerm: String) async throws -> [Track]
}



class MusicServiceImpl: MusicService {
    func fetchSongs() async throws -> MusicItemCollection<Song> {
        do {
            let response = try await MusicLibraryRequest<Song>().response()
            return response.items
        } catch {
            //            handleError(error, context: "Fetching songs failed")
            throw error
        }
    }
    
    func fetchLibraryPlaylists() async throws -> MusicItemCollection<Playlist> {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 100
        let response = try await request.response()

        var playlistsWithTracks: [Playlist] = []
        for playlist in response.items {
            let detailedPlaylist = try await playlist.with(.tracks)
            playlistsWithTracks.append(detailedPlaylist)
        }
        return MusicItemCollection(playlistsWithTracks)
    }

    func fetchCatalogPlaylistTracks(searchTerm: String) async throws -> [Track] {
        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Playlist.self])
        request.limit = 10
        let response = try await request.response()

        for playlist in response.playlists {
            let detailedPlaylist = try await playlist.with(.tracks)
            let tracks = Array(detailedPlaylist.tracks ?? [])
            if !tracks.isEmpty {
                return tracks
            }
        }
        return []
    }
}
