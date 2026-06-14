import Foundation

struct PlayedTrackInfo: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artistName: String
}
