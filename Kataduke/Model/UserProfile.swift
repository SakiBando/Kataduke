import Foundation

struct UserProfile {
    let name: String
    let iconURL: URL?
    let accountCode: String
}

struct FriendProfile: Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
}
