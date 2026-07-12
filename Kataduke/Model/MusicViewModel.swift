import Foundation
import MusicKit
import MediaPlayer

class MusicViewModel: ObservableObject {
    private let musicService: MusicService
    
    @Published var songs: MusicItemCollection<Song> = []
    @Published var appleMusicPlaylists: MusicItemCollection<Playlist> = []
    @Published var localSongs: [MPMediaItem] = []
    @Published var localPlaylists: [MPMediaPlaylist] = []
    @Published var canPlayCatalogContent: Bool = false
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

    func fetchSubscriptionStatus() async -> Bool {
        do {
            let subscription = try await MusicSubscription.current
            DispatchQueue.main.async {
                self.canPlayCatalogContent = subscription.canPlayCatalogContent
            }
            return subscription.canPlayCatalogContent
        } catch {
            DispatchQueue.main.async {
                self.canPlayCatalogContent = false
            }
            print(error)
            return false
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

    func fetchAppleMusicPlaylists() async {
        guard authorizationStatus == .authorized else {
            print("not authorized")
            return
        }
        
        do {
            let result = try await musicService.fetchLibraryPlaylists()
            DispatchQueue.main.async {
                self.appleMusicPlaylists = result
            }
        } catch {
            print(error)
        }
    }

    func fetchLocalSongs() async {
        let status = MPMediaLibrary.authorizationStatus()
        guard status == .authorized else {
            let newStatus = await requestLocalLibraryAuthorization()
            guard newStatus == .authorized else {
                print("local music not authorized")
                return
            }
            loadLocalSongs()
            return
        }
        loadLocalSongs()
    }

    func fetchLocalPlaylists() async {
        let status = MPMediaLibrary.authorizationStatus()
        guard status == .authorized else {
            let newStatus = await requestLocalLibraryAuthorization()
            guard newStatus == .authorized else {
                print("local playlist not authorized")
                return
            }
            loadLocalPlaylists()
            return
        }
        loadLocalPlaylists()
    }

    private func loadLocalSongs() {
        let query = MPMediaQuery.songs()
        let items = query.items ?? []
        DispatchQueue.main.async {
            self.localSongs = items
        }
    }

    private func loadLocalPlaylists() {
        let query = MPMediaQuery.playlists()
        let collections = query.collections as? [MPMediaPlaylist] ?? []
        DispatchQueue.main.async {
            self.localPlaylists = collections
        }
    }

    private func requestLocalLibraryAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
