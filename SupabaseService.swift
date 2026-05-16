import Foundation
import UIKit

// MARK: - Supabase Models (spécifiques au service)

struct SBProfile: Codable, Identifiable, Equatable {
    let id: String
    var username: String
    var displayName: String
    let colorSeed: String
    let createdAt: String
    var updatedAt: String?
    var avatarURL: String?
    var phone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case colorSeed = "color_seed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case avatarURL = "avatar_url"
        case phone
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
    var ownerName: String
    let dateKey: String
    let colorName: String
    let colorHex: String
    let caption: String
    let createdAt: String?
    var likesCount: Int?
    var userHasLiked: Bool?
    /// URLs des 9 images stockées dans Supabase Storage
    var imageUrls: [String]?
    /// Transforms for each image: [{ox, oy, scale}, ...]
    var imageTransforms: [SBImageTransform]?
    var ownerAvatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case dateKey = "date_key"
        case colorName = "color_name"
        case colorHex = "color_hex"
        case caption
        case createdAt = "created_at"
        case likesCount = "likes_count"
        case userHasLiked = "user_has_liked"
        case imageUrls = "image_urls"
        case imageTransforms = "image_transforms"
        case ownerAvatarURL = "owner_avatar_url"
    }
}

struct SBImageTransform: Codable, Equatable {
    let ox: Double
    let oy: Double
    let scale: Double
}

struct SBComment: Codable, Identifiable, Equatable {
    let id: String?
    let frameId: Int
    let userId: String
    let body: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case frameId = "frame_id"
        case userId = "user_id"
        case body
        case createdAt = "created_at"
    }
}

// MARK: - SupabaseService

/// Couche d'accès à Supabase (cloud managé).
/// Remplace CloudKitService pour le backend social, l'auth et le stockage.
@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    // MARK: - État publié

    @Published var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published private(set) var needsOnboarding = false
    @Published var needsTutorial = false
    @Published private(set) var currentProfile: SBProfile?
    @Published private(set) var friends: [SBProfile] = []
    @Published private(set) var incomingRequests: [SBFriendship] = []
    @Published private(set) var feedFrames: [SBFramePost] = []
    @Published private(set) var comments: [SBComment] = []
    @Published var searchResults: [SBProfile] = []
    @Published var statusMessage: String?
    @Published var taskLoading = false

    // MARK: - Endpoints Supabase

    private let baseURL: String
    private let anonKey: String
    private let session: URLSession

    private init() {
        self.baseURL = SupabaseConfig.url
        self.anonKey = SupabaseConfig.publishableKey
        self.session = URLSession.shared
    }

    // MARK: - Helpers HTTP

    var restURL: String { "\(baseURL)/rest/v1" }
    var authURL: String { "\(baseURL)/auth/v1" }
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
        let urlString = "\(restURL)\(path)"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = method
        req.allHTTPHeaderFields = defaultHeaders.merging(extraHeaders) { _, new in new }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
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
        needsOnboarding = false
        _ = try? await fetchProfile()
    }

    func signIn(email: String, password: String) async throws {
        let body = ["email": email, "password": password]
        let (data, _) = try await post(path: "/auth/v1/token?grant_type=password", body: body, isAuth: true)
        let session = try JSONDecoder().decode(SBAuthSession.self, from: data)
        saveSession(session)
        await resolveAccountState()
    }

    func signOut() async {
        let token = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken") ?? ""
        _ = try? await post(path: "/auth/v1/logout", body: [:], isAuth: true, token: token)
        clearSession()
    }

    // MARK: - OAuth (Apple / Google)

    func signInWithApple(idToken: String, nonce: String? = nil) async throws {
        var body: [String: Any] = [
            "id_token": idToken,
            "provider": "apple"
        ]
        if let nonce {
            body["nonce"] = nonce
        }
        let (data, _) = try await post(path: "/auth/v1/token?grant_type=id_token", body: body, isAuth: true)
        let session = try JSONDecoder().decode(SBAuthSession.self, from: data)
        saveSession(session)
        await resolveAccountState()
    }

    func signInWithGoogle(idToken: String) async throws {
        let body: [String: Any] = [
            "id_token": idToken,
            "provider": "google"
        ]
        let (data, _) = try await post(path: "/auth/v1/token?grant_type=id_token", body: body, isAuth: true)
        let session = try JSONDecoder().decode(SBAuthSession.self, from: data)
        saveSession(session)
        await resolveAccountState()
    }

    private func resolveAccountState() async {
        if let profile = try? await fetchProfile() {
            // Profil existant : nouveau si username auto-généré, sinon compte existant
            needsOnboarding = profile.username.hasPrefix("user_")
            needsTutorial = false
        } else {
            // Aucun profil trouvé : nouvel utilisateur
            needsOnboarding = true
        }
    }

    func getOAuthURL(provider: String) -> URL {
        URL(string: "\(authURL)/authorize?provider=\(provider)&redirect_to=huntone://auth/callback")!
    }

    func handleOAuthCallback(url: URL) async throws {
        guard let fragment = url.fragment ?? url.query else {
            throw SBError.invalidResponse
        }

        let params = fragment
            .components(separatedBy: "&")
            .reduce(into: [String: String]()) { dict, pair in
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2 { dict[kv[0]] = kv[1] }
            }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw SBError.notAuthenticated
        }

        saveTokens(accessToken: accessToken, refreshToken: refreshToken)

        let userId = try await fetchAuthUserId(accessToken: accessToken)
        UserDefaults.standard.set(userId, forKey: "\(SupabaseConfig.defaultsPrefix).userId")
        isAuthenticated = true

        _ = try? await fetchProfile()
        await resolveAccountState()
    }

    private func fetchAuthUserId(accessToken: String) async throws -> String {
        var req = URLRequest(url: URL(string: "\(authURL)/user")!)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, _) = try await session.data(for: req)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["id"] as? String {
            return id
        }
        throw SBError.invalidResponse
    }

    private func saveTokens(accessToken: String, refreshToken: String) {
        UserDefaults.standard.set(accessToken, forKey: "\(SupabaseConfig.defaultsPrefix).accessToken")
        UserDefaults.standard.set(refreshToken, forKey: "\(SupabaseConfig.defaultsPrefix).refreshToken")
    }

    // MARK: - Onboarding

    func completeOnboarding(username: String, displayName: String = "", bio: String = "", avatarImage: UIImage? = nil, phone: String = "") async throws {
        var avatarURL: String? = nil
        if let avatarImage {
            avatarURL = try await uploadAvatar(avatarImage)
        }

        let finalDisplayName = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? username
            : displayName
        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        _ = try await upsertProfile(username: cleanUsername, displayName: finalDisplayName, avatarURL: avatarURL, bio: bio, phone: phone)
        needsOnboarding = false

        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        guard !userId.isEmpty else { return }
        let frameUpdate: [String: Any] = [
            "owner_name": finalDisplayName,
            "owner_avatar_url": avatarURL ?? ""
        ]
        _ = try? await patch(path: "/frame_posts?owner_id=eq.\(userId)", body: frameUpdate)
        _ = try? await fetchLatestFrames()
    }

    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.count >= 2 else { return false }
        let (data, _) = try await get(path: "/profiles?username=eq.\(clean)&select=id&limit=1")
        let profiles = try JSONDecoder().decode([SBProfile].self, from: data)
        return profiles.isEmpty
    }

    private func bustAvatarURL(_ url: String?, updatedAt: String?) -> String? {
        guard let url else { return nil }
        guard let updatedAt, !updatedAt.isEmpty else { return url }
        return "\(url)?t=\(updatedAt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? updatedAt)"
    }

    private func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw SBError.imageEncodingFailed
        }
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let path = "\(userId)/avatar.jpg"
        let uploadPath = "\(storageURL)/object/avatars/\(path)"

        var req = URLRequest(url: URL(string: uploadPath)!)
        req.httpMethod = "POST"
        var headers: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "image/jpeg",
            "x-upsert": "true"
        ]
        if let auth = defaultHeaders["Authorization"], !auth.isEmpty {
            headers["Authorization"] = auth
        }
        req.allHTTPHeaderFields = headers
        req.httpBody = data

        let (rdata, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: rdata, encoding: .utf8) ?? ""
            print("❌ uploadAvatar failed: \(body)")
            throw SBError.uploadFailed
        }
        return "\(storageURL)/object/public/avatars/\(path)"
    }

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).accessToken"),
              !token.isEmpty else { return }
        isAuthenticated = true
        if let profile = try? await fetchProfile() {
            needsOnboarding = profile.username.hasPrefix("user_")
            needsTutorial = false
        } else {
            clearSession()
        }
    }

    // MARK: - Profiles

    func fetchProfile() async throws -> SBProfile? {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        guard !userId.isEmpty else { return nil }

        let (data, _) = try await get(path: "/profiles?id=eq.\(userId)&select=*")
        let profiles = try JSONDecoder().decode([SBProfile].self, from: data)
        if let profile = profiles.first {
            currentProfile = profile
            return profile
        }

        // Retry après un court délai (le trigger handle_new_user peut être en cours)
        try await Task.sleep(nanoseconds: 500_000_000)
        let (data2, _) = try await get(path: "/profiles?id=eq.\(userId)&select=*")
        let retryProfiles = try JSONDecoder().decode([SBProfile].self, from: data2)
        if let profile = retryProfiles.first {
            currentProfile = profile
            return profile
        }
        return nil
    }

    func upsertProfile(username: String, displayName: String, avatarURL: String? = nil, bio: String? = nil, phone: String? = nil) async throws -> SBProfile {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        guard !userId.isEmpty else { throw SBError.notAuthenticated }

        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "@", with: "")

        var body: [String: Any] = [
            "id": userId,
            "username": cleanUsername,
            "display_name": displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        if let avatarURL { body["avatar_url"] = avatarURL }
        if let bio { body["bio"] = String(bio.prefix(160)) }
        if let phone { body["phone"] = String(phone.prefix(20)) }

        let (data, _) = try await post(path: "/profiles", body: body, extraHeaders: [
            "Prefer": "resolution=merge-duplicates,return=representation"
        ])
        let profiles = try JSONDecoder().decode([SBProfile].self, from: data)
        guard let profile = profiles.first else {
            throw SBError.invalidResponse
        }
        currentProfile = profile
        return profile
    }

    func searchUsers(query: String) async throws -> [SBProfile] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.count >= 2 else { return [] }
        let currentId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let (data, _) = try await get(path: "/profiles?or=(username.ilike.*\(cleaned)*,display_name.ilike.*\(cleaned)*,phone.ilike.*\(cleaned)*)&select=*&limit=20")
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
        statusMessage = String(format: loc("service.request_sent"), profile.username)
    }

    func acceptFriendRequest(_ friendship: SBFriendship) async throws {
        guard let id = friendship.id else { return }
        let body = ["status": "accepted"]
        _ = try await patch(path: "/friendships?id=eq.\(id)", body: body)
        try await refreshFriendships()
        statusMessage = loc("service.friend_added")
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

    func publishFrame(photos: [UIImage?], transforms: [CellTransform], dailyColor: DailyColor, selectedDate: Date, caption: String) async throws {
        let completedPhotos = photos.compactMap { $0 }
        guard completedPhotos.count == 9 else {
            print("❌ publishFrame: only \(completedPhotos.count)/9 photos")
            throw SBError.incompleteFrame
        }

        let dateKey = DailyColorProvider.dateKey(for: selectedDate)
        print("📤 publishFrame: \(dateKey) — \(dailyColor.name) — \(caption)")

        let jsonTransforms = transforms.enumerated().map { (_, t) in
            ["ox": t.offsetX, "oy": t.offsetY, "scale": t.scale]
        }

        guard let profile = currentProfile else {
            print("❌ publishFrame: no profile / not authenticated")
            throw SBError.notAuthenticated
        }

        print("📤 publishFrame: profile=\(profile.id)")

        // 1. Upload les 9 images vers Storage
        let frameId = "\(profile.id)/\(dateKey)"
        var imageUrls: [String] = []

        for (index, image) in completedPhotos.enumerated() {
            let url = try await uploadImage(image, path: "\(frameId)/\(index).jpg")
            imageUrls.append(url)
        }

        print("✅ All 9 images uploaded, creating frame post...")

        // 2. Crée le post dans la DB
        let body: [String: Any] = [
            "owner_id": profile.id,
            "owner_name": profile.displayName,
            "owner_avatar_url": profile.avatarURL ?? "",
            "date_key": dateKey,
            "color_name": dailyColor.name,
            "color_hex": dailyColor.hex,
            "caption": caption,
            "image_urls": imageUrls,
            "image_transforms": jsonTransforms,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        _ = try await post(path: "/frame_posts", body: body, extraHeaders: ["Prefer": "return=minimal"])
        print("✅ Frame post created in Supabase")
    }

    func fetchMyFrames() async throws -> [SBFramePost] {
        guard let profile = currentProfile else { return [] }
        let (data, _) = try await get(path: "/frame_posts?owner_id=eq.\(profile.id)&select=*&order=created_at.desc")
        var frames = try JSONDecoder().decode([SBFramePost].self, from: data)
        let displayName = profile.displayName
        let bustedAvatar = bustAvatarURL(profile.avatarURL, updatedAt: profile.updatedAt)
        for i in frames.indices {
            frames[i].ownerName = displayName
            frames[i].ownerAvatarURL = bustedAvatar
        }
        return frames
    }

    func fetchLatestFrames(limit: Int = 30) async throws -> [SBFramePost] {
        let (data, _) = try await get(path: "/frame_posts?select=*&order=created_at.desc&limit=\(limit)")
        var frames = try JSONDecoder().decode([SBFramePost].self, from: data)

        let ownerIds = Array(Set(frames.map { $0.ownerId }))
        if !ownerIds.isEmpty {
            let filters = ownerIds.map { "id.eq.\($0)" }.joined(separator: ",")
            if let (profileData, _) = try? await get(path: "/profiles?or=(\(filters))&select=id,avatar_url,display_name,updated_at"),
               let profiles = try? JSONDecoder().decode([SBProfile].self, from: profileData) {
                var avatarMap: [String: String] = [:]
                var nameMap: [String: String] = [:]
                for p in profiles {
                    if let url = p.avatarURL {
                        avatarMap[p.id] = bustAvatarURL(url, updatedAt: p.updatedAt)
                    }
                    nameMap[p.id] = p.displayName
                }
                for i in frames.indices {
                    if let url = avatarMap[frames[i].ownerId] {
                        frames[i].ownerAvatarURL = url
                    }
                    if let name = nameMap[frames[i].ownerId], !name.isEmpty {
                        frames[i].ownerName = name
                    }
                }
            }
        }

        feedFrames = frames
        return frames
    }

    func deleteFrame(for dateKey: String) async throws {
        guard let profile = currentProfile else {
            throw SBError.notAuthenticated
        }
        let ownerId = profile.id

        // Supprime la ligne frame_posts (DB) + cascade likes/comments/images
        _ = try await delete(path: "/frame_posts?owner_id=eq.\(ownerId)&date_key=eq.\(dateKey)")

        // Supprime les 9 fichiers JPEG du Storage
        let bucket = SupabaseConfig.framesBucket
        for index in 0..<9 {
            let path = "\(ownerId)/\(dateKey)/\(index).jpg"
            try? await deleteStorageObject(bucket: bucket, path: path)
        }

        feedFrames.removeAll { $0.ownerId == ownerId && $0.dateKey == dateKey }
    }

    func fetchCaption(for dateKey: String) async -> String? {
        guard let profile = currentProfile else { return nil }
        let ownerId = profile.id
        guard let (data, _) = try? await get(path: "/frame_posts?owner_id=eq.\(ownerId)&date_key=eq.\(dateKey)&select=caption&limit=1"),
              let posts = try? JSONDecoder().decode([SBFramePost].self, from: data),
              let post = posts.first else { return nil }
        let parts = post.caption.components(separatedBy: " - ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : nil
    }

    // MARK: - Likes

    func likeFrame(frameId: Int) async throws {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let body: [String: Any] = ["frame_id": frameId, "user_id": userId]
        _ = try await post(path: "/frame_likes", body: body, extraHeaders: ["Prefer": "return=minimal"])
    }

    func unlikeFrame(frameId: Int) async throws {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        _ = try await delete(path: "/frame_likes?frame_id=eq.\(frameId)&user_id=eq.\(userId)")
    }

    // MARK: - Comments

    func postComment(frameId: Int, body: String) async throws {
        let userId = UserDefaults.standard.string(forKey: "\(SupabaseConfig.defaultsPrefix).userId") ?? ""
        let comment: [String: Any] = ["frame_id": frameId, "user_id": userId, "body": body]
        _ = try await post(path: "/frame_comments", body: comment, extraHeaders: ["Prefer": "return=minimal"])
    }

    func fetchComments(frameId: Int) async throws -> [SBComment] {
        let (data, _) = try await get(path: "/frame_comments?frame_id=eq.\(frameId)&select=*&order=created_at.asc")
        let result = try JSONDecoder().decode([SBComment].self, from: data)
        comments = result
        return result
    }

    // MARK: - Storage (upload)

    private func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            print("❌ uploadImage: JPEG encoding failed")
            throw SBError.imageEncodingFailed
        }

        let bucket = SupabaseConfig.framesBucket
        let uploadPath = "\(storageURL)/object/\(bucket)/\(path)"
        print("📤 Uploading to: \(uploadPath)")

        var req = URLRequest(url: URL(string: uploadPath)!)
        req.httpMethod = "POST"

        var headers: [String: String] = [
            "apikey": anonKey,
            "Content-Type": "image/jpeg",
            "x-upsert": "true"
        ]
        if let auth = defaultHeaders["Authorization"], !auth.isEmpty {
            headers["Authorization"] = auth
        }
        req.allHTTPHeaderFields = headers
        req.httpBody = data

        print("📤 Token present: \(defaultHeaders["Authorization"] != nil)")

        let (rdata, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            print("❌ uploadImage: invalid response type")
            throw SBError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: rdata, encoding: .utf8) ?? ""
            print("❌ uploadImage failed: HTTP \(http.statusCode) — \(body)")
            throw SBError.uploadFailed
        }
        print("✅ Uploaded: \(path)")

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
        needsOnboarding = false
        currentProfile = nil
        friends = []
        incomingRequests = []
    }

    private func refreshFriendships() async throws {
        _ = try await fetchIncomingRequests()
        _ = try await fetchFriends()
    }

    // MARK: - HTTP primitives

    func get(path: String) async throws -> (Data, HTTPURLResponse) {
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
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ POST \(urlString) failed: HTTP \(http.statusCode) — \(body)")
            throw SBError.invalidResponse
        }
        return (data, http)
    }

    private func patch(path: String, body: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: "\(restURL)\(path)")!)
        req.httpMethod = "PATCH"
        req.allHTTPHeaderFields = defaultHeaders.merging(["Prefer": "return=representation"]) { _, new in new }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ PATCH \(restURL)\(path) failed: HTTP \(http.statusCode) — \(body)")
            throw SBError.invalidResponse
        }
        return (data, http)
    }

    private func delete(path: String) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: URL(string: "\(restURL)\(path)")!)
        req.httpMethod = "DELETE"
        req.allHTTPHeaderFields = defaultHeaders
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ DELETE \(restURL)\(path) failed: HTTP \(http.statusCode) — \(body)")
            throw SBError.invalidResponse
        }
        return (data, http)
    }

    private func deleteStorageObject(bucket: String, path: String) async throws {
        var req = URLRequest(url: URL(string: "\(storageURL)/object/\(bucket)/\(path)")!)
        req.httpMethod = "DELETE"
        req.allHTTPHeaderFields = defaultHeaders
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SBError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SBError.uploadFailed
        }
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
            return loc("service.not_authenticated")
        case .incompleteFrame:
            return "Le frame doit contenir 9 photos avant publication."
        case .imageEncodingFailed:
            return loc("service.image_encoding_failed")
        case .uploadFailed:
            return loc("service.upload_failed")
        case .invalidResponse:
            return loc("service.invalid_response")
        case .decodingFailed(let detail):
            return "Erreur de parsing: \(detail)"
        }
    }
}
