import CloudKit
import UIKit

final class CloudKitService {
    static let shared = CloudKitService()

    private let container: CKContainer
    private let database: CKDatabase
    private let fileManager: FileManager

    init(container: CKContainer = .default(), fileManager: FileManager = .default) {
        self.container = container
        self.database = container.publicCloudDatabase
        self.fileManager = fileManager
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func currentUserIdentifier() async throws -> String {
        let status = try await accountStatus()
        guard status == .available else {
            throw HuntoneBackendError.iCloudUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let recordID {
                    continuation.resume(returning: recordID.recordName)
                } else {
                    continuation.resume(throwing: HuntoneBackendError.iCloudUnavailable)
                }
            }
        }
    }

    func fetchCurrentProfile() async throws -> HuntoneUser? {
        let userId = try await currentUserIdentifier()
        return try await fetchUser(userId: userId)
    }

    func upsertCurrentProfile(username: String, displayName: String) async throws -> HuntoneUser {
        let userId = try await currentUserIdentifier()
        let recordID = CKRecord.ID(recordName: "user-\(userId)")
        let record: CKRecord

        if let existing = try? await fetchRecord(with: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "UserProfile", recordID: recordID)
            record["createdAt"] = Date() as CKRecordValue
            record["userId"] = userId as CKRecordValue
        }

        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@", with: "")

        record["username"] = cleanUsername as CKRecordValue
        record["displayName"] = displayName.trimmingCharacters(in: .whitespacesAndNewlines) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        let savedRecord = try await save(record)
        guard let profile = HuntoneUser(record: savedRecord) else {
            throw HuntoneBackendError.profileMissing
        }
        return profile
    }

    func searchUsers(query: String) async throws -> [HuntoneUser] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanedQuery.count >= 2 else { return [] }

        let predicate = NSPredicate(format: "username BEGINSWITH %@", cleanedQuery)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "username", ascending: true)]

        let records = try await perform(query)
        let currentId = try? await currentUserIdentifier()
        return records
            .compactMap(HuntoneUser.init(record:))
            .filter { $0.id != currentId }
    }

    func sendFriendRequest(to user: HuntoneUser, from currentUser: HuntoneUser) async throws {
        let recordName = friendshipRecordName(currentUser.id, user.id)
        let recordID = CKRecord.ID(recordName: recordName)
        let record: CKRecord

        if let existing = try? await fetchRecord(with: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "Friendship", recordID: recordID)
            record["createdAt"] = Date() as CKRecordValue
        }

        record["requesterId"] = currentUser.id as CKRecordValue
        record["requesterName"] = currentUser.displayName as CKRecordValue
        record["addresseeId"] = user.id as CKRecordValue
        record["addresseeName"] = user.displayName as CKRecordValue
        record["status"] = FriendStatus.pending.rawValue as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        _ = try await save(record)
    }

    func acceptFriendRequest(_ request: FriendRequest) async throws {
        let record = try await fetchRecord(with: request.id)
        record["status"] = FriendStatus.accepted.rawValue as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await save(record)
    }

    func fetchIncomingRequests(for userId: String) async throws -> [FriendRequest] {
        let predicate = NSPredicate(format: "addresseeId == %@ AND status == %@", userId, FriendStatus.pending.rawValue)
        let query = CKQuery(recordType: "Friendship", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return try await perform(query).compactMap(FriendRequest.init(record:))
    }

    func fetchFriendships(for userId: String) async throws -> [FriendRequest] {
        let predicate = NSPredicate(
            format: "(requesterId == %@ OR addresseeId == %@) AND status == %@",
            userId,
            userId,
            FriendStatus.accepted.rawValue
        )
        let query = CKQuery(recordType: "Friendship", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try await perform(query).compactMap(FriendRequest.init(record:))
    }

    func fetchUsers(ids: [String]) async throws -> [HuntoneUser] {
        var users: [HuntoneUser] = []

        for userId in ids {
            if let user = try await fetchUser(userId: userId) {
                users.append(user)
            }
        }

        return users
    }

    func publishFrame(photos: [UIImage?], dailyColor: DailyColor, selectedDate: Date, caption: String, currentUser: HuntoneUser) async throws {
        let completedPhotos = photos.compactMap { $0 }
        guard completedPhotos.count == 9 else {
            throw HuntoneBackendError.incompleteFrame
        }

        let record = CKRecord(recordType: "FramePost")
        record["ownerId"] = currentUser.id as CKRecordValue
        record["ownerName"] = currentUser.displayName as CKRecordValue
        record["dateKey"] = DailyColorProvider.dateKey(for: selectedDate) as CKRecordValue
        record["colorName"] = dailyColor.name as CKRecordValue
        record["colorHex"] = dailyColor.hex as CKRecordValue
        record["caption"] = caption as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        let assetURLs = try completedPhotos.enumerated().map { index, image in
            try writeTemporaryImage(image, index: index)
        }

        for (index, url) in assetURLs.enumerated() {
            record["image\(index)"] = CKAsset(fileURL: url)
        }

        _ = try await save(record)

        for url in assetURLs {
            try? fileManager.removeItem(at: url)
        }
    }

    func fetchLatestFrames(limit: Int = 30) async throws -> [RemoteFramePost] {
        let query = CKQuery(recordType: "FramePost", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return Array(try await perform(query).compactMap(RemoteFramePost.init(record:)).prefix(limit))
    }

    private func fetchUser(userId: String) async throws -> HuntoneUser? {
        let recordID = CKRecord.ID(recordName: "user-\(userId)")
        guard let record = try? await fetchRecord(with: recordID) else {
            return nil
        }
        return HuntoneUser(record: record)
    }

    private func fetchRecord(with recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
        }
    }

    private func save(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: CKError(.internalError))
                }
            }
        }
    }

    private func perform(_ query: CKQuery) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            database.perform(query, inZoneWith: nil) { records, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: records ?? [])
                }
            }
        }
    }

    private func friendshipRecordName(_ firstId: String, _ secondId: String) -> String {
        [firstId, secondId].sorted().joined(separator: "-")
    }

    private func writeTemporaryImage(_ image: UIImage, index: Int) throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw HuntoneBackendError.imageEncodingFailed
        }

        let directory = fileManager.temporaryDirectory.appendingPathComponent("HuntoneUploads", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString)-\(index).jpg")
        try data.write(to: url, options: [.atomic])
        return url
    }
}
