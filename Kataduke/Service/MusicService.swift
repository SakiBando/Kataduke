import Foundation
import MusicKit

protocol MusicService {
    func fetchSongs() async throws -> MusicItemCollection<Song>
    func fetchLibraryPlaylists() async throws -> MusicItemCollection<Playlist>
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
}

