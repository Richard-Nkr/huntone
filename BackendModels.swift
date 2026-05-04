import Foundation

struct HuntoneUser: Identifiable, Equatable, Codable {
    let id: String
    var username: String
    var displayName: String
    var bio: String
    var avatarUrl: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FriendRequest: Identifiable, Equatable, Codable {
    let id: String
    let requesterId: String
    let addresseeId: String
    let requesterName: String
    let status: FriendStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case requesterName = "requester_name"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        requesterId = try container.decode(String.self, forKey: .requesterId)
        addresseeId = try container.decode(String.self, forKey: .addresseeId)
        requesterName = try container.decode(String.self, forKey: .requesterName)
        let rawStatus = try container.decode(String.self, forKey: .status)
        status = FriendStatus(rawValue: rawStatus) ?? .pending
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum FriendStatus: String, Codable {
    case pending
    case accepted
    case blocked
}

struct RemoteFramePost: Identifiable, Codable {
    let id: String
    let ownerId: String
    let ownerUsername: String
    let ownerDisplayName: String
    let ownerAvatarUrl: String
    let dateKey: String
    let colorName: String
    let colorHex: String
    let caption: String
    let likesCount: Int
    let userHasLiked: Bool
    let images: [FrameImageRef]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerUsername = "owner_username"
        case ownerDisplayName = "owner_display_name"
        case ownerAvatarUrl = "owner_avatar_url"
        case dateKey = "date_key"
        case colorName = "color_name"
        case colorHex = "color_hex"
        case caption
        case likesCount = "likes_count"
        case userHasLiked = "user_has_liked"
        case images
        case createdAt = "created_at"
    }
}

struct FrameImageRef: Codable, Identifiable {
    let position: Int
    let storagePath: String
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case position
        case storagePath = "storage_path"
        case width
        case height
    }

    var id: Int { position }
}

struct FramePostCreate: Codable {
    let ownerId: String
    let dateKey: String
    let colorName: String
    let colorHex: String
    let caption: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case dateKey = "date_key"
        case colorName = "color_name"
        case colorHex = "color_hex"
        case caption
    }
}

struct FrameImageCreate: Codable {
    let frameId: String
    let position: Int
    let storagePath: String
    let width: Int?
    let height: Int?
    let fileSize: Int64?

    enum CodingKeys: String, CodingKey {
        case frameId = "frame_id"
        case position
        case storagePath = "storage_path"
        case width
        case height
        case fileSize = "file_size"
    }
}

enum HuntoneBackendError: LocalizedError {
    case notAuthenticated
    case profileMissing
    case incompleteFrame
    case imageEncodingFailed
    case uploadFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Connecte-toi pour utiliser le profil, les amis et le feed."
        case .profileMissing:
            return "Cree d'abord ton profil Huntone."
        case .incompleteFrame:
            return "Le frame doit contenir 9 photos avant publication."
        case .imageEncodingFailed:
            return "Impossible de preparer les images pour l'envoi."
        case .uploadFailed:
            return "Impossible d'envoyer les images."
        case .apiError(let message):
            return message
        }
    }
}
