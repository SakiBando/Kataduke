import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct SharedCleaningRecordService {
    private let database = Firestore.firestore()
    private let storage = Storage.storage()

    func shareRecord(
        elapsedTime: Double,
        beforeImage: UIImage?,
        afterImage: UIImage?,
        playedTracks: [PlayedTrackInfo],
        beforeTidinessScore: Int?,
        afterTidinessScore: Int?,
        improvementScore: Int?
    ) async throws -> String {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw SharedCleaningRecordError.notLoggedIn
        }

        let profileSnapshot = try await database.collection("users").document(currentUserID).getDocument()
        let profileData = profileSnapshot.data() ?? [:]
        let ownerName = profileData["name"] as? String ?? "名前なし"
        let ownerIconURL = profileData["iconURL"] as? String

        let friendsSnapshot = try await database
            .collection("users")
            .document(currentUserID)
            .collection("friends")
            .getDocuments()
        let friendIDs = friendsSnapshot.documents.map {
            $0.data()["friendUserID"] as? String ?? $0.documentID
        }

        guard !friendIDs.isEmpty else {
            throw SharedCleaningRecordError.noFriends
        }

        let recordID = UUID().uuidString
        async let beforeURL = uploadSharedImage(
            ownerUserID: currentUserID,
            recordID: recordID,
            name: "before",
            image: beforeImage
        )
        async let afterURL = uploadSharedImage(
            ownerUserID: currentUserID,
            recordID: recordID,
            name: "after",
            image: afterImage
        )

        let playedTracksData = try JSONEncoder().encode(playedTracks)
        let playedTracksObject = (try JSONSerialization.jsonObject(with: playedTracksData)) as? [[String: Any]] ?? []

        var values: [String: Any] = [
            "ownerUserID": currentUserID,
            "ownerName": ownerName,
            "elapsedTime": elapsedTime,
            "playedTracks": playedTracksObject,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let ownerIconURL {
            values["ownerIconURL"] = ownerIconURL
        }
        if let beforeURL = try await beforeURL {
            values["beforeImageURL"] = beforeURL.absoluteString
        }
        if let afterURL = try await afterURL {
            values["afterImageURL"] = afterURL.absoluteString
        }
        if let beforeTidinessScore {
            values["beforeTidinessScore"] = beforeTidinessScore
        }
        if let afterTidinessScore {
            values["afterTidinessScore"] = afterTidinessScore
        }
        if let improvementScore {
            values["improvementScore"] = improvementScore
        }

        for friendID in friendIDs {
            try await database
                .collection("users")
                .document(friendID)
                .collection("sharedRecords")
                .document(recordID)
                .setData(values, merge: true)
        }
        return recordID
    }

    func fetchSharedRecords() async throws -> [SharedCleaningRecord] {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw SharedCleaningRecordError.notLoggedIn
        }

        let snapshot = try await database
            .collection("users")
            .document(currentUserID)
            .collection("sharedRecords")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        var records: [SharedCleaningRecord] = []
        for document in snapshot.documents {
            let data = document.data()
            let playedTrackObjects = data["playedTracks"] as? [[String: Any]] ?? []
            let playedTracks = playedTrackObjects.compactMap { object -> PlayedTrackInfo? in
                guard let id = object["id"] as? String,
                      let title = object["title"] as? String,
                      let artistName = object["artistName"] as? String else {
                    return nil
                }
                return PlayedTrackInfo(id: id, title: title, artistName: artistName)
            }
            let likesDocuments = (try? await document.reference.collection("likes").getDocuments())?.documents ?? []
            let isLikedByCurrentUser = likesDocuments.contains { $0.documentID == currentUserID }

            records.append(SharedCleaningRecord(
                id: document.documentID,
                ownerUserID: data["ownerUserID"] as? String ?? "",
                ownerName: data["ownerName"] as? String ?? "名前なし",
                ownerIconURL: (data["ownerIconURL"] as? String).flatMap(URL.init(string:)),
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                elapsedTime: data["elapsedTime"] as? Double ?? 0,
                beforeImageURL: (data["beforeImageURL"] as? String).flatMap(URL.init(string:)),
                afterImageURL: (data["afterImageURL"] as? String).flatMap(URL.init(string:)),
                playedTracks: playedTracks,
                beforeTidinessScore: data["beforeTidinessScore"] as? Int,
                afterTidinessScore: data["afterTidinessScore"] as? Int,
                improvementScore: data["improvementScore"] as? Int,
                likeCount: likesDocuments.count,
                isLikedByCurrentUser: isLikedByCurrentUser
            ))
        }
        return records
    }

    func deleteSharedRecord(recordID: String) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw SharedCleaningRecordError.notLoggedIn
        }
        guard !recordID.isEmpty else { return }

        let friendsSnapshot = try await database
            .collection("users")
            .document(currentUserID)
            .collection("friends")
            .getDocuments()
        let friendIDs = friendsSnapshot.documents.map {
            $0.data()["friendUserID"] as? String ?? $0.documentID
        }

        for friendID in friendIDs {
            let recordReference = database
                .collection("users")
                .document(friendID)
                .collection("sharedRecords")
                .document(recordID)
            let likesSnapshot = try await recordReference.collection("likes").getDocuments()
            for likeDocument in likesSnapshot.documents {
                try await likeDocument.reference.delete()
            }
            try await recordReference.delete()
        }

        let storageReference = storage.reference().child("sharedRecords/\(currentUserID)/\(recordID)")
        try? await storageReference.child("before.jpg").delete()
        try? await storageReference.child("after.jpg").delete()
    }

    func toggleLike(recordID: String, isLikedByCurrentUser: Bool) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            throw SharedCleaningRecordError.notLoggedIn
        }

        let likeReference = database
            .collection("users")
            .document(currentUserID)
            .collection("sharedRecords")
            .document(recordID)
            .collection("likes")
            .document(currentUserID)

        if isLikedByCurrentUser {
            try await likeReference.delete()
        } else {
            try await likeReference.setData([
                "userID": currentUserID,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    private func uploadSharedImage(
        ownerUserID: String,
        recordID: String,
        name: String,
        image: UIImage?
    ) async throws -> URL? {
        guard let image else { return nil }
        guard let data = image.jpegData(compressionQuality: 0.75) else {
            throw SharedCleaningRecordError.invalidImage
        }

        let reference = storage.reference().child("sharedRecords/\(ownerUserID)/\(recordID)/\(name).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }
}

enum SharedCleaningRecordError: LocalizedError {
    case notLoggedIn
    case invalidImage
    case noFriends

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "ログイン情報を確認できませんでした。"
        case .invalidImage:
            return "共有する画像を保存できる形式に変換できませんでした。"
        case .noFriends:
            return "共有できる友達がまだいません。"
        }
    }
}
