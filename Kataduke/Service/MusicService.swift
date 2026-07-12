import Foundation
import MusicKit

protocol MusicService {
    func fetchSongs() async throws -> MusicItemCollection<Song>
    // ⭐️ 追加：おすすめプレイリスト取得
    func fetchRecommendedPlaylist() async throws -> MusicItemCollection<Playlist>
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
    
    func fetchRecommendedPlaylist() async throws -> MusicItemCollection<Playlist> {
           do {
               let request = MusicPersonalRecommendationsRequest()
               let response = try await request.response()
               
               // recommendationの中からplaylistsだけ集める
               var playlists: [Playlist] = []
               
               for recommendation in response.recommendations {
                   
                   playlists.append(contentsOf: recommendation.playlists)
                   print("タイトル：", recommendation.title ?? "")
                   print("プレイリスト数：", recommendation.playlists.count)
               }
               
               return MusicItemCollection(playlists)
               
           } catch {
               print("Fetching recommendations failed:", error)
               throw error
           }
       }
}


