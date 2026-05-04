import SwiftUI

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var currentUser: HuntoneUser?
    @Published private(set) var searchResults: [HuntoneUser] = []
    @Published private(set) var friends: [HuntoneUser] = []
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var remoteFrames: [RemoteFramePost] = []
    @Published var username: String = ""
    @Published var displayName: String = ""
    @Published var searchQuery: String = ""
    @Published var publishCaption: String = ""
    @Published var statusMessage: String?
    @Published var isLoading = false
    @Published var isSignedIn = false
    @Published var email: String = ""
    @Published var password: String = ""

    private let service: SupabaseService

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    var isReady: Bool {
        isSignedIn && currentUser != nil
    }

    // MARK: - Auth

    func signUp() async {
        await runLoadingTask {
            let (user, token) = try await service.signUp(
                email: email,
                password: password,
                username: username,
                displayName: displayName
            )
            service.setAccessToken(token)
            currentUser = user
            isSignedIn = true
            username = user.username
            displayName = user.displayName
            statusMessage = "Compte cree et connecte."
        }
    }

    func signIn() async {
        await runLoadingTask {
            let (user, token) = try await service.signIn(email: email, password: password)
            service.setAccessToken(token)
            currentUser = user
            isSignedIn = true
            username = user.username
            displayName = user.displayName
            statusMessage = "Connecte."
        }
    }

    func refresh() async {
        await runLoadingTask {
            if let token = loadToken() {
                service.setAccessToken(token)
                isSignedIn = true
            }

            currentUser = try await service.fetchCurrentProfile()

            if let currentUser {
                username = currentUser.username
                displayName = currentUser.displayName
                isSignedIn = true
                try await refreshRelationships()
            }

            remoteFrames = try await service.fetchFeed()
        }
    }

    func saveProfile() async {
        await runLoadingTask {
            let user = try await service.upsertProfile(
                username: username,
                displayName: displayName.isEmpty ? username : displayName
            )
            currentUser = user
            username = user.username
            displayName = user.displayName
            try await refreshRelationships()
            statusMessage = "Profil sauvegarde."
        }
    }

    func searchUsers() async {
        await runLoadingTask {
            searchResults = try await service.searchUsers(query: searchQuery)
        }
    }

    func sendFriendRequest(to user: HuntoneUser) async {
        await runLoadingTask {
            try await service.sendFriendRequest(to: user)
            statusMessage = "Demande envoyee a @\(user.username)."
        }
    }

    func accept(_ request: FriendRequest) async {
        await runLoadingTask {
            try await service.acceptFriendRequest(request)
            try await refreshRelationships()
            statusMessage = "Ami ajoute."
        }
    }

    func publishFrame(from viewModel: HuntoneViewModel) async {
        await runLoadingTask {
            guard let currentUser else {
                throw HuntoneBackendError.profileMissing
            }

            try await service.publishFrame(
                photos: viewModel.photos,
                dailyColor: viewModel.dailyColor,
                selectedDate: viewModel.selectedDate,
                caption: publishCaption,
                currentUser: currentUser
            )

            publishCaption = ""
            remoteFrames = try await service.fetchFeed()
            statusMessage = "Frame publie."
        }
    }

    // MARK: - Likes

    func likeFrame(_ frameId: String) async {
        await runLoadingTask {
            try await service.likeFrame(frameId)
        }
    }

    func unlikeFrame(_ frameId: String) async {
        await runLoadingTask {
            try await service.unlikeFrame(frameId)
        }
    }

    // MARK: - Private

    private func refreshRelationships() async throws {
        incomingRequests = try await service.fetchIncomingRequests()
        friends = try await service.fetchFriends()
    }

    private func runLoadingTask(_ task: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await task()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "huntone.auth.token")
    }

    private func loadToken() -> String? {
        UserDefaults.standard.string(forKey: "huntone.auth.token")
    }
}
