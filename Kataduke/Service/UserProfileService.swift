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
        let iconURL = (data["iconURL"] as? String).flatMap(URL.init(string:))
        let accountCode = data["accountCode"] as? String ?? makeAccountCode(from: userID)
        return UserProfile(name: name, iconURL: iconURL, accountCode: accountCode)
    }

    func saveProfile(userID: String, name: String, iconImage: UIImage?) async throws -> UserProfile {
        let accountCode = try await ensureAccountCode(userID: userID)
        var iconURL: URL?
        if let iconImage {
            iconURL = try await uploadIcon(userID: userID, image: iconImage)
        } else if let existing = try await fetchProfile(userID: userID) {
            iconURL = existing.iconURL
        }

        var values: [String: Any] = [
            "name": name,
            "accountCode": accountCode,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        values["age"] = FieldValue.delete()
        if let iconURL {
            values["iconURL"] = iconURL.absoluteString
        }

        try await database.collection("users").document(userID).setData(values, merge: true)
        try await database.collection("friendCodes").document(accountCode).setData([
            "userID": userID,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return UserProfile(name: name, iconURL: iconURL, accountCode: accountCode)
    }

    func ensureAccountCode(userID: String) async throws -> String {
        let userReference = database.collection("users").document(userID)
        let snapshot = try await userReference.getDocument()
        if let accountCode = snapshot.data()?["accountCode"] as? String, !accountCode.isEmpty {
            try await database.collection("friendCodes").document(accountCode).setData([
                "userID": userID,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            return accountCode
        }

        let accountCode = makeAccountCode(from: userID)
        try await userReference.setData([
            "accountCode": accountCode,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        try await database.collection("friendCodes").document(accountCode).setData([
            "userID": userID,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        return accountCode
    }

    func addFriend(currentUserID: String, friendCode: String) async throws {
        let normalizedCode = friendCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else {
            throw UserProfileError.emptyFriendCode
        }

        let codeSnapshot = try await database.collection("friendCodes").document(normalizedCode).getDocument()
        guard let friendUserID = codeSnapshot.data()?["userID"] as? String else {
            throw UserProfileError.friendCodeNotFound
        }
        guard friendUserID != currentUserID else {
            throw UserProfileError.cannotAddSelf
        }

        let friendSnapshot = try await database.collection("users").document(friendUserID).getDocument()
        guard friendSnapshot.exists else {
            throw UserProfileError.friendProfileNotFound
        }

        let batch = database.batch()
        let currentUserFriendReference = database
            .collection("users")
            .document(currentUserID)
            .collection("friends")
            .document(friendUserID)
        let friendUserFriendReference = database
            .collection("users")
            .document(friendUserID)
            .collection("friends")
            .document(currentUserID)

        batch.setData([
            "friendUserID": friendUserID,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: currentUserFriendReference, merge: true)
        batch.setData([
            "friendUserID": currentUserID,
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: friendUserFriendReference, merge: true)
        try await batch.commit()
    }

    func fetchFriends(userID: String) async throws -> [FriendProfile] {
        let snapshot = try await database
            .collection("users")
            .document(userID)
            .collection("friends")
            .order(by: "createdAt", descending: false)
            .getDocuments()

        var friends: [FriendProfile] = []
        for document in snapshot.documents {
            let friendUserID = document.data()["friendUserID"] as? String ?? document.documentID
            let profileSnapshot = try await database.collection("users").document(friendUserID).getDocument()
            guard let data = profileSnapshot.data() else { continue }

            friends.append(
                FriendProfile(
                    id: friendUserID,
                    name: data["name"] as? String ?? "名前なし",
                    iconURL: (data["iconURL"] as? String).flatMap(URL.init(string:))
                )
            )
        }
        return friends
    }

    func deleteProfileData(userID: String) async throws {
        let profile = try await fetchProfile(userID: userID)
        let friendsSnapshot = try await database
            .collection("users")
            .document(userID)
            .collection("friends")
            .getDocuments()

        let batch = database.batch()
        for document in friendsSnapshot.documents {
            let friendUserID = document.data()["friendUserID"] as? String ?? document.documentID
            batch.deleteDocument(document.reference)
            batch.deleteDocument(
                database
                    .collection("users")
                    .document(friendUserID)
                    .collection("friends")
                    .document(userID)
            )
        }

        if let accountCode = profile?.accountCode, !accountCode.isEmpty {
            batch.deleteDocument(database.collection("friendCodes").document(accountCode))
        }
        batch.deleteDocument(database.collection("users").document(userID))
        try await batch.commit()

        try? await storage.reference().child("profileIcons/\(userID)/icon.jpg").delete()
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

    private func makeAccountCode(from userID: String) -> String {
        String(userID.uppercased().prefix(8))
    }
}

enum UserProfileError: LocalizedError {
    case invalidImage
    case emptyFriendCode
    case friendCodeNotFound
    case friendProfileNotFound
    case cannotAddSelf

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "アイコン画像を保存できる形式に変換できませんでした。"
        case .emptyFriendCode:
            return "友達のアカウントコードを入力してください。"
        case .friendCodeNotFound:
            return "このアカウントコードのユーザーが見つかりませんでした。"
        case .friendProfileNotFound:
            return "友達のプロフィールが見つかりませんでした。"
        case .cannotAddSelf:
            return "自分自身は友達に追加できません。"
        }
    }
}
