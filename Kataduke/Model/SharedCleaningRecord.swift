import Foundation

struct SharedCleaningRecord: Identifiable {
    let id: String
    let ownerUserID: String
    let ownerName: String
    let ownerIconURL: URL?
    let createdAt: Date
    let elapsedTime: Double
    let beforeImageURL: URL?
    let afterImageURL: URL?
    let playedTracks: [PlayedTrackInfo]
    let beforeTidinessScore: Int?
    let afterTidinessScore: Int?
    let improvementScore: Int?
    let likeCount: Int
    let isLikedByCurrentUser: Bool
}
