import Foundation
import MusicKit

class MusicViewModel: ObservableObject {
    private let musicService: MusicService
    
    @Published var songs: MusicItemCollection<Song> = []
    @Published var recommendedPlayLisits: MusicItemCollection<Playlist> = []
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    
    init(musicService: MusicService) {
        self.musicService = musicService
    }
    
    func authorize() async {
        let status = await MusicAuthorization.request()
        DispatchQueue.main.async { [self] in
            authorizationStatus = status
        }
    }
    
    func fetchSongs() async throws {
        guard authorizationStatus == .authorized else {
            print("not authorized")
            return
        }
        
        do {
            let result = try await musicService.fetchSongs()
            DispatchQueue.main.async {
                self.songs = result
            }
        } catch {
            print(error)
        }
    }
    
    func fetchRecommendedPlaylists() async {
           guard authorizationStatus == .authorized else {
               print("not authorized")
               return
           }
           
           do {
               let result = try await musicService.fetchRecommendedPlaylist()
               DispatchQueue.main.async {
                   self.recommendedPlayLisits = result
               }
           } catch {
               print(error)
           }
       }
}





