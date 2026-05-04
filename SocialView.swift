import SwiftUI

struct SocialView: View {
    @EnvironmentObject private var challengeViewModel: HuntoneViewModel
    @EnvironmentObject private var socialViewModel: SocialViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    accountSection
                    publishSection
                    friendsSection
                    searchSection
                    requestsSection
                    remoteFramesSection
                }
                .padding(24)
                .padding(.bottom, 90)
            }
            .background(Color.white)
            .navigationBarHidden(true)
            .task {
                await socialViewModel.refresh()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("SOCIAL")
                .font(.custom("ClashDisplay-Bold", size: 28))
                .foregroundColor(.black)

            Spacer()

            if socialViewModel.isLoading {
                ProgressView()
            } else {
                Button {
                    Task { await socialViewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.top, 24)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("COMPTE")

            if socialViewModel.isSignedIn {
                Text("CONNECTE")
                    .font(.custom("ClashDisplay-Medium", size: 11))
                    .foregroundColor(Color(UIColor.systemGray))

                TextField("username", text: $socialViewModel.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(UIColor.systemGray6))

                TextField("Nom affiche", text: $socialViewModel.displayName)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(UIColor.systemGray6))

                Button {
                    Task { await socialViewModel.saveProfile() }
                } label: {
                    Text("SAUVEGARDER PROFIL")
                        .font(.custom("ClashDisplay-Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.black)
                }
            } else {
                TextField("Email", text: $socialViewModel.email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(UIColor.systemGray6))

                SecureField("Mot de passe", text: $socialViewModel.password)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(UIColor.systemGray6))

                TextField("username", text: $socialViewModel.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(UIColor.systemGray6))

                HStack(spacing: 10) {
                    Button {
                        Task { await socialViewModel.signIn() }
                    } label: {
                        Text("CONNEXION")
                            .font(.custom("ClashDisplay-Bold", size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(Color.black)
                    }

                    Button {
                        Task { await socialViewModel.signUp() }
                    } label: {
                        Text("INSCRIPTION")
                            .font(.custom("ClashDisplay-Bold", size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.black)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 1.5)
                            )
                    }
                }
            }

            if let statusMessage = socialViewModel.statusMessage {
                Text(statusMessage)
                    .font(.custom("ClashDisplay-Regular", size: 13))
                    .foregroundColor(Color(UIColor.systemGray))
            }
        }
    }

    private var publishSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("PUBLIER")

            TextField("Legende du frame", text: $socialViewModel.publishCaption)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color(UIColor.systemGray6))

            Button {
                Task { await socialViewModel.publishFrame(from: challengeViewModel) }
            } label: {
                HStack {
                    Text("PUBLIER LE FRAME DU JOUR")
                    Spacer()
                    Text(challengeViewModel.progressLabel)
                }
                .font(.custom("ClashDisplay-Bold", size: 13))
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .foregroundColor(challengeViewModel.canExport && socialViewModel.isReady ? .white : Color(UIColor.systemGray3))
                .background(challengeViewModel.canExport && socialViewModel.isReady ? Color.black : Color(UIColor.systemGray6))
            }
            .disabled(!challengeViewModel.canExport || !socialViewModel.isReady)
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("AMIS")

            if socialViewModel.friends.isEmpty {
                emptyText("Aucun ami ajoute.")
            } else {
                ForEach(socialViewModel.friends) { user in
                    userRow(user, trailing: "AMI")
                }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("AJOUTER")

            HStack(spacing: 10) {
                TextField("chercher un username", text: $socialViewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color(UIColor.systemGray6))

                Button {
                    Task { await socialViewModel.searchUsers() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 48, height: 48)
                        .foregroundColor(.white)
                        .background(Color.black)
                }
            }

            ForEach(socialViewModel.searchResults) { user in
                Button {
                    Task { await socialViewModel.sendFriendRequest(to: user) }
                } label: {
                    userRow(user, trailing: "AJOUTER")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("DEMANDES")

            if socialViewModel.incomingRequests.isEmpty {
                emptyText("Aucune demande en attente.")
            } else {
                ForEach(socialViewModel.incomingRequests) { request in
                    Button {
                        Task { await socialViewModel.accept(request) }
                    } label: {
                        HStack {
                            Text(request.requesterName)
                                .font(.custom("ClashDisplay-Medium", size: 15))
                                .foregroundColor(.black)
                            Spacer()
                            Text("ACCEPTER")
                                .font(.custom("ClashDisplay-Bold", size: 10))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var remoteFramesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("BASE DE DONNEES")

            if socialViewModel.remoteFrames.isEmpty {
                emptyText("Aucun frame CloudKit charge.")
            } else {
                ForEach(socialViewModel.remoteFrames) { frame in
                    HStack {
                        Rectangle()
                            .fill(Color(uiColor: UIColor(hex: frame.colorHex)))
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(frame.ownerName)
                                .font(.custom("ClashDisplay-Medium", size: 14))
                                .foregroundColor(.black)
                            Text("\(frame.dateKey) · \(frame.colorName.uppercased())")
                                .font(.custom("ClashDisplay-Regular", size: 12))
                                .foregroundColor(Color(UIColor.systemGray))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.custom("ClashDisplay-Bold", size: 12))
            .foregroundColor(.black)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.custom("ClashDisplay-Regular", size: 13))
            .foregroundColor(Color(UIColor.systemGray))
    }

    private func userRow(_ user: HuntoneUser, trailing: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.custom("ClashDisplay-Medium", size: 15))
                    .foregroundColor(.black)
                Text("@\(user.username)")
                    .font(.custom("ClashDisplay-Regular", size: 12))
                    .foregroundColor(Color(UIColor.systemGray))
            }

            Spacer()

            Text(trailing)
                .font(.custom("ClashDisplay-Bold", size: 10))
                .foregroundColor(.black)
        }
    }
}
