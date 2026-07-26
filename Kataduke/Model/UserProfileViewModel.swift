import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var iconImage: UIImage?
    @Published var iconURL: URL?
    @Published var accountCode = ""
    @Published var friendCode = ""
    @Published var friends: [FriendProfile] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isAddingFriend = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let service = UserProfileService()

    func load() async {
        guard let user = Auth.auth().currentUser else { return }
        let userID = user.uid
        email = user.email ?? ""
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let profile = try await service.fetchProfile(userID: userID) else { return }
            name = profile.name
            iconURL = profile.iconURL
            accountCode = profile.accountCode
            try await loadFriends(userID: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "ログイン情報を確認できませんでした。"
            return
        }
        let userID = user.uid
        email = user.email ?? ""
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名前を入力してください。"
            return
        }

        isSaving = true
        message = nil
        errorMessage = nil
        defer { isSaving = false }

        do {
            let profile = try await service.saveProfile(
                userID: userID,
                name: trimmedName,
                iconImage: iconImage
            )
            name = profile.name
            iconURL = profile.iconURL
            accountCode = profile.accountCode
            iconImage = nil
            message = "プロフィールを保存しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareAccountCodeIfNeeded() async {
        guard accountCode.isEmpty, let userID = Auth.auth().currentUser?.uid else { return }
        do {
            accountCode = try await service.ensureAccountCode(userID: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFriend() async -> Bool {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報を確認できませんでした。"
            return false
        }

        isAddingFriend = true
        message = nil
        errorMessage = nil
        defer { isAddingFriend = false }

        do {
            try await service.addFriend(currentUserID: userID, friendCode: friendCode)
            friendCode = ""
            try await loadFriends(userID: userID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshFriends() async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        do {
            try await loadFriends(userID: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFriends(userID: String) async throws {
        friends = try await service.fetchFriends(userID: userID)
    }
}
