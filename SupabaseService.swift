import Foundation
import UIKit

// MARK: - Supabase Models (spécifiques au service)

struct SBProfile: Codable, Identifiable, Equatable {
    let id: String
    var username: String
    var displayName: String
    let createdAt: String
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SBFriendship: Codable, Identifiable, Equatable {
    let id: Int?
    let requesterId: String
    let addresseeId: String
    let status: String // "pending" | "accepted"
    let requesterName: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case requesterName = "requester_name"
        case createdAt = "created_at"
    }
}

struct SBFramePost: Codable, Identifiable, Equatable {
    let id: Int?
    let ownerId: String
    let ownerName: String
    let dateKey: String
    let colorName: String
    let colorHex: String
    let caption: String
    let createdAt: String?
    /// URLs des 9 images stockées dans Supabase Storage
    var imageUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case dateKey = "date_key"
        case colorName = "color_name"
        case colorHex = "color_hex"
        case caption
        case createdAt = "created_at"
        case imageUrls = "image_urls"
    }
}

// MARK: - SupabaseService

/// Couche d'accès à Supabase (cloud managé).
/// Remplace CloudKitService pour le backend social, l'auth et le stockage.
@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    // MARK: - État publié

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentProfile: SBProfile?
    @Published private(set) var friends: [SBProfile] = []
    @Published private(set) var incomingRequests: [SBFriendship] = []
    @Published private(set) var feedFrames: [SBFramePost] = []
    @Published private(set) var searchResults: [SBProfile] = []
    @Published var statusMessage: String?
    @Published var isLoading = false

    // MARK: - Endpoints Supabase

    private let baseURL: String
    private let anonKey: String
    private let session: URLSession

    private init() {
        self.baseURL = SupabaseConfig.url
        self.anonKey = SupabaseConfig.anonKey
        self.session = URLSession.shared
    }

    // MARK: - Helpers HTTP

    private var restURL: String { "\(baseURL)/rest/v1" }
    private var authURL: String { "\(baseURL)/auth/v1" }
    private var storageURL: String { "\(baseURL)/storage/v1" }

    private var defaultHeaders: [String: String] {
        var headers: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "application/json"
        ]
        if let token = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken") {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    private func request(_ method: String, path: String, body: Data? = nil, extraHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var urlString = "\(restURL)\(path)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = method
        req.allHTTPHeaderFields = defaultHeaders.merging(extraHeaders) { _, new in new }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        return (data, http)
    }

    // MARK: - Auth

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["username": username, "display_name": displayName]
        ]
        let (data, _) = try await post(path: "/auth/v1/signup", body: body, isAuth: true)
        let session = try JSONDecoder().decode(SBAuthSession.self, from: data)
        saveSession(session)
        // Le trigger SQL crée le profil automatiquement
        try await refreshProfile()
    }

    func signIn(email: String, password: String) async throws {
        let body = ["email": email, "password": password]
        let (data, _) = try await post(path: "/auth/v1/token?grant_type=password", body: body, isAuth: true)
        let session = try JSONDecoder().decode(SBAuthSession.self, from: data)
        saveSession(session)
        try await refreshProfile()
    }

    func signOut() async throws {
        let token = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken") ?? ""
        _ = try await post(path: "/auth/v1/logout", body: [:], isAuth: true, token: token)
        clearSession()
    }

    func restoreSession() async {
        guard let token = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken"),
              !token.isEmpty else { return }
        // Vérifie que le token est encore valide
        do {
            try await refreshProfile()
        } catch {
            clearSession()
        }
    }

    // MARK: - Profiles

    func fetchProfile() async throws -> SBProfile? {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        guard !userId.isEmpty else { return nil }

        let (data, _) = try await get(path: "/profiles?id=eq.\(userId)&select=*")
        let profiles = try JSONDecoder().decode([SBProfile].self, from: data)
        let profile = profiles.first
        if let profile {
            currentProfile = profile
        }
        return profile
    }

    func upsertProfile(username: String, displayName: String) async throws -> SBProfile {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@", with: "")

        let body: [String: Any] = [
            "id": userId,
            "username": cleanUsername,
            "display_name": displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        let (data, _) = try await post(path: "/profiles", body: body, extraHeaders: ["Prefer": "resolution=merge-duplicates"])

        if let profile = try? JSONDecoder().decode(SBProfile.self, from: data) {
            currentProfile = profile
            return profile
        }
        // Fallback : refetch
        return try await fetchProfile()!
    }

    func searchUsers(query: String) async throws -> [SBProfile] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.count >= 2 else { return [] }
        let currentId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""

        let (data, _) = try await get(path: "/profiles?username=ilike.\(cleaned)*&select=*&limit=20")
        var results = try JSONDecoder().decode([SBProfile].self, from: data)
        results.removeAll { $0.id == currentId }
        searchResults = results
        return results
    }

    // MARK: - Friendships

    func sendFriendRequest(to profile: SBProfile) async throws {
        let myId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let myName = currentProfile?.displayName ?? ""

        let body: [String: Any] = [
            "requester_id": myId,
            "addressee_id": profile.id,
            "requester_name": myName,
            "status": "pending"
        ]
        _ = try await post(path: "/friendships", body: body, extraHeaders: ["Prefer": "return=minimal"])
        statusMessage = "Demande envoyée à @\(profile.username)."
    }

    func acceptFriendRequest(_ friendship: SBFriendship) async throws {
        guard let id = friendship.id else { return }
        let body = ["status": "accepted"]
        _ = try await patch(path: "/friendships?id=eq.\(id)", body: body)
        try await refreshFriendships()
        statusMessage = "Ami ajouté."
    }

    func fetchIncomingRequests() async throws -> [SBFriendship] {
        let myId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let (data, _) = try await get(path: "/friendships?addressee_id=eq.\(myId)&status=eq.pending&select=*")
        let requests = try JSONDecoder().decode([SBFriendship].self, from: data)
        incomingRequests = requests
        return requests
    }

    func fetchFriends() async throws -> [SBProfile] {
        let myId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""

        // Récupère les friendships acceptées
        let (data, _) = try await get(path: "/friendships?or=(requester_id.eq.\(myId),addressee_id.eq.\(myId))&status=eq.accepted&select=requester_id,addressee_id")
        let friendships = try JSONDecoder().decode([SBFriendship].self, from: data)

        let friendIds = friendships.compactMap { f -> String? in
            f.requesterId == myId ? f.addresseeId : f.requesterId
        }
        guard !friendIds.isEmpty else {
            friends = []
            return []
        }

        // Fetch les profils des amis
        let idsFilter = friendIds.map { "id.eq.\($0)" }.joined(separator: ",")
        let (profilesData, _) = try await get(path: "/profiles?or=(\(idsFilter))&select=*")
        let profiles = try JSONDecoder().decode([SBProfile].self, from: profilesData)
        friends = profiles
        return profiles
    }

    // MARK: - Frames

    func publishFrame(photos: [UIImage?], dailyColor: DailyColor, selectedDate: Date, caption: String) async throws {
        let completedPhotos = photos.compactMap { $0 }
        guard completedPhotos.count == 9 else {
            throw SBError.incompleteFrame
        }
        guard let profile = currentProfile else {
            throw SBError.notAuthenticated
        }

        // 1. Upload les 9 images vers Storage
        let dateKey = DailyColorProvider.dateKey(for: selectedDate)
        let frameId = "\(profile.id)/\(dateKey)"
        var imageUrls: [String] = []

        for (index, image) in completedPhotos.enumerated() {
            let url = try await uploadImage(image, path: "\(frameId)/\(index).jpg")
            imageUrls.append(url)
        }

        // 2. Crée le post dans la DB
        let body: [String: Any] = [
            "owner_id": profile.id,
            "owner_name": profile.displayName,
            "date_key": dateKey,
            "color_name": dailyColor.name,
            "color_hex": dailyColor.hex,
            "caption": caption,
            "image_urls": imageUrls,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        _ = try await post(path: "/frame_posts", body: body, extraHeaders: ["Prefer": "return=minimal"])
    }

    func fetchLatestFrames(limit: Int = 30) async throws -> [SBFramePost] {
        let (data, _) = try await get(path: "/frame_posts?select=*&order=created_at.desc&limit=\(limit)")
        let frames = try JSONDecoder().decode([SBFramePost].self, from: data)
        feedFrames = frames
        return frames
    }

    // MARK: - Storage (upload)

    private func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw SBError.imageEncodingFailed
        }

        let bucket = SupabaseConfig.framesBucket
        let uploadPath = "\(storageURL)/object/\(bucket)/\(path)"

        var req = URLRequest(url: URL(string: uploadPath)!)
        req.httpMethod = "POST"
        req.allHTTPHeaderFields = [
            "apikey": anonKey,
            "Authorization": defaultHeaders["Authorization"] ?? "",
            "Content-Type": "image/jpeg",
            "x-upsert": "true"
        ]
        req.httpBody = data

        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SBError.uploadFailed
        }

        // URL publique de l'image
        return "\(storageURL)/object/public/\(bucket)/\(path)"
    }

    // MARK: - Session

    private func saveSession(_ session: SBAuthSession) {
        UserDefaults.standard.set(session.accessToken, forKey: "\(SupabaseConfig.defaultsPrefix).accessToken")
        UserDefaults.standard.set(session.refreshToken, forKey: "\(SupabaseConfig.defaultsPrefix).refreshToken")
        UserDefaults.standard.set(session.user.id, forKey: "\(SupabaseConfig.defaultsPrefix).userId")
        isAuthenticated = true
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken")
        UserDefaults.standard.removeObject(forKey: "\(SupabaseConfig.defaultsPrefix).refreshToken")
        UserDefaults.standard.removeObject(forKey: "\(SupabaseConfig.defaultsPrefix).userId")
        isAuthenticated = false
        currentProfile = nil
        friends = []
        incomingRequests = []
    }

    private func refreshProfile() async throws {
        _ = try await fetchProfile()
    }

    private func refreshFriendships() async throws {
        _ = try await fetchIncomingRequests()
        _ = try await fetchFriends()
    }

    // MARK: - HTTP primitives

    private func get(path: String) async throws -> (Data, HTTPURLResponse) {
        try await request("GET", path: path)
    }

    private func post(path: String, body: [String: Any], isAuth: Bool = false, token: String? = nil, extraHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        let base = isAuth ? authURL : restURL
        var urlString = "\(base)\(path.replacingOccurrences(of: "/auth/v1", with: ""))"
        if isAuth {
            urlString = "\(base)\(path.replacingOccurrences(of: "/auth/v1/", with: "/"))"
        }

        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        var headers: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "application/json"
        ]
        if let token {
            headers["Authorization"] = "Bearer \(token)"
        } else if let savedToken = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken"), !isAuth {
            headers["Authorization"] = "Bearer \(savedToken)"
        }
        for (k, v) in extraHeaders {
            headers[k] = v
        }
        req.allHTTPHeaderFields = headers

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        return (data, http)
    }

    private func patch(path: String, body: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: "\(restURL)\(path)")!)
        req.httpMethod = "PATCH"
        req.allHTTPHeaderFields = defaultHeaders.merging(["Prefer": "return=minimal"]) { _, new in new }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        return (data, http)
    }
}

// MARK: - Auth Models

private struct SBAuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SBAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SBAuthUser: Codable {
    let id: String
    let email: String?
}

// MARK: - Errors

enum SBError: LocalizedError {
    case notAuthenticated
    case incompleteFrame
    case imageEncodingFailed
    case uploadFailed
    case invalidResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Connecte-toi d'abord à ton compte Huntone."
        case .incompleteFrame:
            return "Le frame doit contenir 9 photos avant publication."
        case .imageEncodingFailed:
            return "Impossible de préparer les images pour l'envoi."
        case .uploadFailed:
            return "Échec de l'upload vers Supabase Storage."
        case .invalidResponse:
            return "Réponse invalide du serveur."
        case .decodingFailed(let detail):
            return "Erreur de parsing: \(detail)"
        }
    }
}
