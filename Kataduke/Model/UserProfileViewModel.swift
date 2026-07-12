import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var age = ""
    @Published var iconImage: UIImage?
    @Published var iconURL: URL?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let service = UserProfileService()

    func load() async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let profile = try await service.fetchProfile(userID: userID) else { return }
            name = profile.name
            age = profile.age > 0 ? String(profile.age) : ""
            iconURL = profile.iconURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン情報を確認できませんでした。"
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名前を入力してください。"
            return
        }
        guard let ageValue = Int(age), (1...120).contains(ageValue) else {
            errorMessage = "年齢は1〜120の数字で入力してください。"
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
                age: ageValue,
                iconImage: iconImage
            )
            name = profile.name
            age = String(profile.age)
            iconURL = profile.iconURL
            iconImage = nil
            message = "プロフィールを保存しました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
