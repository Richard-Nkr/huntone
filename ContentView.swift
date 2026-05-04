import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @State private var selectedTab = 0
    @State private var isShowingCreate = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                FeedView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(0)

                ProfileView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(1)
            }
            .preferredColorScheme(.light)

            // Custom Icon Tab Bar
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 0) {
                    Button(action: { selectedTab = 0 }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 24, weight: selectedTab == 0 ? .bold : .regular))
                            .foregroundColor(selectedTab == 0 ? .black : Color(UIColor.systemGray2))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }

                    Button {
                        isShowingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }

                    Button(action: { selectedTab = 1 }) {
                        Image(systemName: "person")
                            .font(.system(size: 24, weight: selectedTab == 1 ? .bold : .regular))
                            .foregroundColor(selectedTab == 1 ? .black : Color(UIColor.systemGray2))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color.white.ignoresSafeArea(edges: .bottom))
        }
        .sheet(isPresented: $isShowingCreate) {
            ChallengeView()
        }
    }
}

struct ChallengeView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingSlotActions = false
    @State private var isShowingShareSheet = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    photoGrid
                    controls
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
            .confirmationDialog("Photo \(viewModel.selectedSlot + 1)", isPresented: $isShowingSlotActions, titleVisibility: .visible) {
                Button("Caméra") {
                    isShowingCamera = true
                }

                Button("Choisir dans Photos") {
                    isShowingPhotoLibrary = true
                }

                if viewModel.photos[viewModel.selectedSlot] != nil {
                    Button("Supprimer", role: .destructive) {
                        viewModel.deletePhoto(at: viewModel.selectedSlot)
                    }
                }

                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    viewModel.save(image, at: viewModel.selectedSlot)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let shareImage = viewModel.shareImage {
                    ShareSheet(image: shareImage)
                }
            }
            .photosPicker(isPresented: $isShowingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    await loadPhoto(item)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.refreshDailyColorIfNeeded()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                Rectangle()
                    .fill(viewModel.dailyColor.swiftUIColor)
                    .frame(width: 80, height: 80)
                    .accessibilityLabel(viewModel.dailyColor.accessibilityLabel)

                VStack(alignment: .leading, spacing: 6) {
                    Text("COULEUR DU JOUR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(viewModel.dailyColor.name.uppercased())
                        .font(.system(size: 32, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(viewModel.dailyColor.hex)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.top, 16)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<9, id: \.self) { index in
                Button {
                    viewModel.selectedSlot = index
                    isShowingSlotActions = true
                } label: {
                    PhotoTile(
                        image: viewModel.photos[index],
                        index: index,
                        tint: viewModel.dailyColor.swiftUIColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Button {
                viewModel.prepareShareImage()
                isShowingShareSheet = viewModel.shareImage != nil
            } label: {
                Text("EXPORTER LE FRAME")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.canExport ? Color.primary : Color(UIColor.systemGray6))
                    .foregroundStyle(viewModel.canExport ? Color(UIColor.systemBackground) : Color(UIColor.systemGray3))
            }
            .disabled(!viewModel.canExport)
            
            Text(viewModel.canExport ? "PRÊT À PARTAGER." : "\(viewModel.filledCount)/9 SÉLECTIONNÉES")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 16)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard
            let item,
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            return
        }

        await MainActor.run {
            viewModel.save(image, at: viewModel.selectedSlot)
            selectedPhotoItem = nil
        }
    }
}

private struct PhotoTile: View {
    let image: UIImage?
    let index: Int
    let tint: Color

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipped()
    }
}
import SwiftUI

enum ProfileTabType: String, CaseIterable {
    case grids = "GRILLES"
    case social = "SOCIAL"
}

struct ProfileView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @EnvironmentObject private var supabase: SupabaseService
    @State private var selectedTab: ProfileTabType = .grids
    @State private var isShowingSupabaseAuth = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    accountInfo
                    tabSelector
                    
                    if selectedTab == .grids {
                        gridsContent
                    } else {
                        socialContent
                    }
                }
                .padding(24)
                .padding(.bottom, 80) // Padding for custom tab bar
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
    }
    
    private var header: some View {
        HStack(alignment: .bottom) {
            Text("PROFIL")
                .font(.custom("ClashDisplay-Bold", size: 28))
                .foregroundColor(.black)
            
            Spacer()
        }
        .padding(.top, 24)
    }

    private var accountInfo: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                // Avatar
                Circle()
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("R")
                            .font(.custom("ClashDisplay-Bold", size: 32))
                            .foregroundColor(.white)
                    )
                
                // Stats
                HStack(spacing: 24) {
                    StatView(value: "\(viewModel.availableDates.count)", label: "Grilles")
                    StatView(value: "120", label: "Abonnés")
                    StatView(value: "45", label: "Suivis")
                }
                .frame(maxWidth: .infinity)
            }
            
            // Bio & Details
            VStack(alignment: .leading, spacing: 4) {
                Text("@richaskip")
                    .font(.custom("ClashDisplay-Bold", size: 18))
                    .foregroundColor(.black)
                Text("Chasseur de couleurs quotidien. Paris.")
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
            }
            
            // Edit Button
            Button(action: {}) {
                Text("ÉDITER LE PROFIL")
                    .font(.custom("ClashDisplay-Bold", size: 12))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
            }
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 32) {
            ForEach(ProfileTabType.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.custom("ClashDisplay-Bold", size: 16))
                        .foregroundColor(selectedTab == tab ? .black : Color(UIColor.systemGray4))
                }
            }
            Spacer()
        }
    }

    private var gridsContent: some View {
        Group {
            if viewModel.availableDates.isEmpty {
                Text("Aucune grille n'a été créée pour le moment.")
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.top, 40)
            } else {
                VStack(spacing: 48) {
                    ForEach(viewModel.availableDates, id: \.self) { date in
                        HistoryGrid(date: date)
                    }
                }
            }
        }
    }

    private var socialContent: some View {
        VStack(spacing: 32) {
            // ── Supabase ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                Text("SUPABASE")
                    .font(.custom("ClashDisplay-Bold", size: 12))
                    .foregroundColor(.black)

                if supabase.isAuthenticated, let profile = supabase.currentProfile {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(String(profile.username.prefix(1)).uppercased())
                                    .font(.custom("ClashDisplay-Bold", size: 18))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(profile.username)")
                                .font(.custom("ClashDisplay-Bold", size: 16))
                                .foregroundColor(.black)
                            Text("Connecté · \(supabase.friends.count) amis")
                                .font(.custom("ClashDisplay-Medium", size: 12))
                                .foregroundColor(Color(UIColor.systemGray))
                        }
                        Spacer()
                        Button("Déco") {
                            Task { try? await supabase.signOut() }
                        }
                        .font(.custom("ClashDisplay-Bold", size: 11))
                        .foregroundColor(.red)
                    }
                } else {
                    Button {
                        isShowingSupabaseAuth = true
                    } label: {
                        Text("CONNECTER AVEC SUPABASE")
                            .font(.custom("ClashDisplay-Bold", size: 12))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                    }
                }
            }

            Divider()

            // ── CloudKit Social ──────────────────────────────
            SocialUserRow(username: "richaskip", subtitle: "24 grilles communes", isFollowing: true)
            SocialUserRow(username: "julien", subtitle: "Nouveau sur Huntone", isFollowing: false)
            SocialUserRow(username: "alexis", subtitle: "12 amis en commun", isFollowing: false)
        }
        .padding(.top, 16)
        .sheet(isPresented: $isShowingSupabaseAuth) {
            SupabaseAuthView()
        }
    }
}

private struct SocialUserRow: View {
    let username: String
    let subtitle: String
    @State var isFollowing: Bool

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(UIColor.systemGray6))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(username.prefix(1)).uppercased())
                        .font(.custom("ClashDisplay-Bold", size: 18))
                        .foregroundColor(.black)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("@\(username)")
                    .font(.custom("ClashDisplay-Bold", size: 16))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.custom("ClashDisplay-Medium", size: 12))
                    .foregroundColor(Color(UIColor.systemGray))
            }

            Spacer()

            Button(action: {
                isFollowing.toggle()
            }) {
                Text(isFollowing ? "SUIVI" : "SUIVRE")
                    .font(.custom("ClashDisplay-Bold", size: 12))
                    .foregroundColor(isFollowing ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color(UIColor.systemGray6) : .black)
            }
        }
    }
}

private struct HistoryGrid: View {
    let date: Date
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @State private var photos: [UIImage?] = Array(repeating: nil, count: 9)
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date).uppercased()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let color = DailyColorProvider.color(for: date)
            
            HStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 16, height: 16)
                
                Text(formattedDate)
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text("\(photos.compactMap { $0 }.count)/9")
                    .font(.custom("ClashDisplay-Medium", size: 12))
                    .foregroundColor(Color(UIColor.systemGray))
            }
            
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<9, id: \.self) { index in
                    MiniPhotoTile(image: photos[index], tint: color.swiftUIColor)
                }
            }
        }
        .task {
            photos = viewModel.fetchPhotos(for: date)
        }
    }
}

private struct MiniPhotoTile: View {
    let image: UIImage?
    let tint: Color

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipped()
    }
}

private struct StatView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("ClashDisplay-Bold", size: 18))
                .foregroundColor(.black)
            Text(label)
                .font(.custom("ClashDisplay-Medium", size: 12))
                .foregroundColor(Color(UIColor.systemGray))
        }
    }
}
