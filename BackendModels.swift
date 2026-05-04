import CloudKit
import Foundation

struct HuntoneUser: Identifiable, Equatable {
    let id: String
    var username: String
    var displayName: String
    var createdAt: Date

    init(id: String, username: String, displayName: String, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.createdAt = createdAt
    }

    init?(record: CKRecord) {
        guard
            let userId = record["userId"] as? String,
            let username = record["username"] as? String,
            let displayName = record["displayName"] as? String
        else {
            return nil
        }

        self.id = userId
        self.username = username
        self.displayName = displayName
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
}

struct FriendRequest: Identifiable, Equatable {
    let id: CKRecord.ID
    let requesterId: String
    let addresseeId: String
    let requesterName: String
    let status: FriendStatus
    let createdAt: Date

    init?(record: CKRecord) {
        guard
            let requesterId = record["requesterId"] as? String,
            let addresseeId = record["addresseeId"] as? String,
            let requesterName = record["requesterName"] as? String,
            let rawStatus = record["status"] as? String,
            let status = FriendStatus(rawValue: rawStatus)
        else {
            return nil
        }

        self.id = record.recordID
        self.requesterId = requesterId
        self.addresseeId = addresseeId
        self.requesterName = requesterName
        self.status = status
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
}

enum FriendStatus: String {
    case pending
    case accepted
}

struct RemoteFramePost: Identifiable {
    let id: CKRecord.ID
    let ownerId: String
    let ownerName: String
    let dateKey: String
    let colorName: String
    let colorHex: String
    let caption: String
    let createdAt: Date

    init?(record: CKRecord) {
        guard
            let ownerId = record["ownerId"] as? String,
            let ownerName = record["ownerName"] as? String,
            let dateKey = record["dateKey"] as? String,
            let colorName = record["colorName"] as? String,
            let colorHex = record["colorHex"] as? String
        else {
            return nil
        }

        self.id = record.recordID
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.dateKey = dateKey
        self.colorName = colorName
        self.colorHex = colorHex
        self.caption = record["caption"] as? String ?? ""
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
}

enum HuntoneBackendError: LocalizedError {
    case iCloudUnavailable
    case profileMissing
    case incompleteFrame
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "Connecte-toi a iCloud pour utiliser le profil, les amis et le feed."
        case .profileMissing:
            return "Cree d'abord ton profil Huntone."
        case .incompleteFrame:
            return "Le frame doit contenir 9 photos avant publication."
        case .imageEncodingFailed:
            return "Impossible de preparer les images pour l'envoi."
        }
    }
}
