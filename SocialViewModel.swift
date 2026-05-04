import CloudKit
import SwiftUI

@MainActor
final class SocialViewModel: ObservableObject {
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
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

    private let service: CloudKitService

    init(service: CloudKitService = .shared) {
        self.service = service
    }

    var isReady: Bool {
        accountStatus == .available && currentUser != nil
    }

    var accountStatusLabel: String {
        switch accountStatus {
        case .available:
            return "iCloud connecte"
        case .noAccount:
            return "Aucun compte iCloud"
        case .restricted:
            return "iCloud restreint"
        case .couldNotDetermine:
            return "Verification iCloud"
        case .temporarilyUnavailable:
            return "iCloud temporairement indisponible"
        @unknown default:
            return "Statut iCloud inconnu"
        }
    }

    func refresh() async {
        await runLoadingTask {
            accountStatus = try await service.accountStatus()
            currentUser = try await service.fetchCurrentProfile()

            if let currentUser {
                username = currentUser.username
                displayName = currentUser.displayName
                try await refreshRelationships(for: currentUser)
            }

            remoteFrames = try await service.fetchLatestFrames()
        }
    }

    func saveProfile() async {
        await runLoadingTask {
            let fallbackDisplayName = displayName.isEmpty ? username : displayName
            let user = try await service.upsertCurrentProfile(username: username, displayName: fallbackDisplayName)
            currentUser = user
            username = user.username
            displayName = user.displayName
            try await refreshRelationships(for: user)
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
            guard let currentUser else {
                throw HuntoneBackendError.profileMissing
            }

            try await service.sendFriendRequest(to: user, from: currentUser)
            statusMessage = "Demande envoyee a @\(user.username)."
        }
    }

    func accept(_ request: FriendRequest) async {
        await runLoadingTask {
            try await service.acceptFriendRequest(request)

            if let currentUser {
                try await refreshRelationships(for: currentUser)
            }

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
            remoteFrames = try await service.fetchLatestFrames()
            statusMessage = "Frame publie."
        }
    }

    private func refreshRelationships(for user: HuntoneUser) async throws {
        incomingRequests = try await service.fetchIncomingRequests(for: user.id)
        let friendships = try await service.fetchFriendships(for: user.id)
        let friendIds = friendships.map { friendship in
            friendship.requesterId == user.id ? friendship.addresseeId : friendship.requesterId
        }
        friends = try await service.fetchUsers(ids: friendIds)
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
}
