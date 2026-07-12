import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct UserProfileService {
    private let database = Firestore.firestore()
    private let storage = Storage.storage()

    func fetchProfile(userID: String) async throws -> UserProfile? {
        let snapshot = try await database.collection("users").document(userID).getDocument()
        guard let data = snapshot.data() else { return nil }

        let name = data["name"] as? String ?? ""
        let age = data["age"] as? Int ?? 0
        let iconURL = (data["iconURL"] as? String).flatMap(URL.init(string:))
        return UserProfile(name: name, age: age, iconURL: iconURL)
    }

    func saveProfile(userID: String, name: String, age: Int, iconImage: UIImage?) async throws -> UserProfile {
        var iconURL: URL?
        if let iconImage {
            iconURL = try await uploadIcon(userID: userID, image: iconImage)
        } else if let existing = try await fetchProfile(userID: userID) {
            iconURL = existing.iconURL
        }

        var values: [String: Any] = [
            "name": name,
            "age": age,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let iconURL {
            values["iconURL"] = iconURL.absoluteString
        }

        try await database.collection("users").document(userID).setData(values, merge: true)
        return UserProfile(name: name, age: age, iconURL: iconURL)
    }

    private func uploadIcon(userID: String, image: UIImage) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw UserProfileError.invalidImage
        }

        let reference = storage.reference().child("profileIcons/\(userID)/icon.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }
}

enum UserProfileError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "アイコン画像を保存できる形式に変換できませんでした。"
    }
}
