import SwiftUI

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

enum ProfileTabType: String, CaseIterable {
    case grids = "profile.grids_tab"
    case social = "profile.social_tab"

    var label: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }
}

struct ProfileView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @EnvironmentObject private var supabase: SupabaseService
    @State private var selectedTab: ProfileTabType = .grids
    @State private var fullScreenDate: Date?
    @State private var myFrames: [SBFramePost] = []
    @State private var searchQuery = ""
    @State private var selectedUserId: String?
    @State private var selectedUsername: String?
    @State private var showEditProfile = false

    private var framesByDateKey: [String: SBFramePost] {
        Dictionary(uniqueKeysWithValues: myFrames.map { ($0.dateKey, $0) })
    }

    private var allGridDates: [Date] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "fr_FR")
        return myFrames.compactMap { formatter.date(from: $0.dateKey) }.sorted(by: >)
    }

    var body: some View {
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
            .padding(.bottom, 80)
        }
        .background(Color.white)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(
                username: supabase.currentProfile?.username ?? "",
                avatarURL: supabase.currentProfile?.avatarURL
            )
            .environmentObject(supabase)
        }
        .onAppear {
            viewModel.refreshAvailableDates()
            Task {
                if let frames = try? await supabase.fetchMyFrames() {
                    myFrames = frames
                    let remoteKeys = Set(frames.map { $0.dateKey })
                    viewModel.cleanupOrphanedGrids(keeping: remoteKeys)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            Text(loc("profile.title"))
                .font(.custom("ClashDisplay-Bold", size: 28))
                .foregroundColor(.black)
            Spacer()
            Button {
                LanguageManager.shared.toggle()
            } label: {
                Text(LanguageManager.shared.current.uppercased())
                    .font(.custom("ClashDisplay-Bold", size: 12))
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Account Info

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.black)
            .frame(width: 80, height: 80)
            .overlay(
                Text(supabase.currentProfile?.username.prefix(1).uppercased() ?? "H")
                    .font(.custom("ClashDisplay-Bold", size: 32))
                    .foregroundColor(.white)
            )
    }

    private var accountInfo: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 20) {
                if let avatarURL = supabase.currentProfile?.avatarURL,
                   let updatedAt = supabase.currentProfile?.updatedAt {
                    let cacheBustedURL = URL(string: "\(avatarURL)?t=\(updatedAt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? updatedAt)")
                    if let url = cacheBustedURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color.black
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }
                } else if let avatarURL = supabase.currentProfile?.avatarURL,
                          let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.black
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                HStack(spacing: 24) {
                    StatView(value: "\(allGridDates.count)", label: loc("profile.stats_grids"))
                    StatView(value: "\(supabase.friends.count)", label: loc("profile.stats_friends"))
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let profile = supabase.currentProfile {
                    Text("@\(profile.username)")
                        .font(.custom("ClashDisplay-Bold", size: 18))
                        .foregroundColor(.black)
                } else {
                    Text("@huntone")
                        .font(.custom("ClashDisplay-Bold", size: 18))
                        .foregroundColor(.black)
                }
                Text(loc("profile.bio"))
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
            }

            if supabase.isAuthenticated {
                HStack(spacing: 10) {
                    Button(action: { showEditProfile = true }) {
                        Text(loc("profile.edit_button"))
                            .font(.custom("ClashDisplay-Bold", size: 12))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.systemGray6))
                    }

                    Button {
                        Task { await supabase.signOut() }
                    } label: {
                        Text(loc("profile.logout_button"))
                            .font(.custom("ClashDisplay-Bold", size: 12))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 32) {
            ForEach(ProfileTabType.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.label)
                        .font(.custom("ClashDisplay-Bold", size: 16))
                        .foregroundColor(selectedTab == tab ? .black : Color(UIColor.systemGray4))
                }
            }
            Spacer()
        }
    }

    // MARK: - Grids Content

    private var gridsContent: some View {
        Group {
            if allGridDates.isEmpty {
                Text(loc("profile.no_grids"))
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.top, 40)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(allGridDates, id: \.self) { date in
                        let dateKey = DailyColorProvider.dateKey(for: date)
                        ProfileGridCell(date: date, supabaseFrame: framesByDateKey[dateKey])
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                fullScreenDate = date
                            }
                    }
                }
            }
        }
        .fullScreenCover(item: $fullScreenDate) { date in
            let dateKey = DailyColorProvider.dateKey(for: date)
            ProfileGridFullView(date: date, supabaseFrame: framesByDateKey[dateKey]) { deletedKey in
                myFrames.removeAll { $0.dateKey == deletedKey }
                viewModel.cleanupOrphanedGrids(keeping: Set(myFrames.map { $0.dateKey }))
            }
            .environmentObject(viewModel)
            .environmentObject(supabase)
        }
    }

    // MARK: - Social Content

    private var socialContent: some View {
        VStack(spacing: 24) {
            searchBar

            if !supabase.incomingRequests.isEmpty {
                sectionHeader(loc("profile.requests_title"), count: supabase.incomingRequests.count)
                ForEach(supabase.incomingRequests) { request in
                    IncomingRequestRow(request: request) {
                        Task {
                            _ = try? await supabase.acceptFriendRequest(request)
                            _ = try? await supabase.fetchFriends()
                            _ = try? await supabase.fetchIncomingRequests()
                        }
                    }
                }
            }

            sectionHeader(loc("profile.friends_title"), count: supabase.friends.count)

            if supabase.friends.isEmpty {
                Text(loc("profile.friends_empty"))
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.top, 8)
            } else {
                ForEach(supabase.friends) { friend in
                    Button {
                        selectedUserId = friend.id
                        selectedUsername = friend.username
                    } label: {
                        SocialUserRow(
                            avatarURL: friend.avatarURL,
                            username: friend.username,
                            subtitle: friend.displayName.isEmpty ? "@\(friend.username)" : friend.displayName,
                            showButton: false
                        ) {}
                    }
                    .buttonStyle(.plain)
                }
            }

            if !supabase.searchResults.isEmpty {
                sectionHeader(loc("profile.discover_title"))
                ForEach(supabase.searchResults) { user in
                    SocialUserRow(
                        avatarURL: user.avatarURL,
                        username: user.username,
                        subtitle: user.displayName.isEmpty ? "@\(user.username)" : user.displayName,
                        showButton: true
                    ) {
                        Task {
                            try? await supabase.sendFriendRequest(to: user)
                        }
                    }
                }
            }

            if let msg = supabase.statusMessage {
                Text(msg)
                    .font(.custom("ClashDisplay-Regular", size: 13))
                    .foregroundColor(Color(UIColor.systemGray))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            inviteSection
        }
        .padding(.top, 8)
        .task {
            _ = try? await supabase.fetchFriends()
            _ = try? await supabase.fetchIncomingRequests()
        }
        .sheet(item: Binding(
            get: { selectedUserId.map { UserProfileSheet(id: $0, username: selectedUsername ?? "") } },
            set: { _ in selectedUserId = nil }
        )) { sheet in
            UserProfileView(userId: sheet.id, username: sheet.username)
                .environmentObject(supabase)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(Color(UIColor.systemGray))
            TextField(loc("profile.search_placeholder"), text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.custom("ClashDisplay-Medium", size: 14))
                .onSubmit {
                    Task { try? await supabase.searchUsers(query: searchQuery) }
                }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    supabase.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor.systemGray))
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private let inviteMessage = loc("profile.invite_message") + "\nhttps://apps.apple.com/app/huntone/idXXXXXXXXXX"

    // MARK: - Invite Section

    private var inviteSection: some View {
        VStack(spacing: 12) {
            Divider()
            ShareLink(item: inviteMessage) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18)).foregroundColor(.black)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("profile.invite_title"))
                            .font(.custom("ClashDisplay-Bold", size: 14))
                            .foregroundColor(.black)
                        Text(loc("profile.invite_subtitle"))
                            .font(.custom("ClashDisplay-Medium", size: 12))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18)).foregroundColor(.black)
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String, count: Int? = nil) -> some View {
        HStack {
            Text(title)
                .font(.custom("ClashDisplay-Bold", size: 12))
                .foregroundColor(.black)
            if let count {
                Text("(\(count))")
                    .font(.custom("ClashDisplay-Medium", size: 12))
                    .foregroundColor(Color(UIColor.systemGray))
            }
            Spacer()
        }
    }
}

// MARK: - Profile Grid Cell

private struct ProfileGridCell: View {
    let date: Date
    let supabaseFrame: SBFramePost?
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @State private var photos: [UIImage?] = Array(repeating: nil, count: 9)

    private var remoteURLs: [String] {
        supabaseFrame?.imageUrls ?? []
    }

    var body: some View {
        let color: DailyColor = {
            if let hex = supabaseFrame?.colorHex {
                return DailyColor.from(hex: hex)
            }
            return viewModel.gridColor(for: date) ?? DailyColorProvider.color(for: date, userSeed: nil)
        }()
        GeometryReader { geo in
            let tileWidth = max(1, geo.size.width / 3)
            VStack(spacing: 0) {
                ForEach(0..<3) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { col in
                            let index = row * 3 + col
                            if let image = photos[index] {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3).clipped()
                            } else if index < remoteURLs.count, let url = URL(string: remoteURLs[index]) {
                                SupabaseImage(url: url, fallbackColor: color.swiftUIColor.opacity(0.08))
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3).clipped()
                            } else {
                                color.swiftUIColor.opacity(0.15 + Double(index % 3) * 0.05)
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3)
                            }
                        }
                    }
                }
            }
        }
        .task { photos = viewModel.fetchPhotos(for: date) }
    }
}

// MARK: - Profile Grid Full Screen View

private struct ProfileGridFullView: View {
    let date: Date
    let supabaseFrame: SBFramePost?
    var onDelete: ((String) -> Void)?
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var photos: [UIImage?] = Array(repeating: nil, count: 9)
    @State private var transforms: [CellTransform] = []
    @State private var publishedCity: String?
    @State private var remoteImageURLs: [String] = []
    @State private var isLoadingShare = false
    @State private var selectedTileIndex: Int?

    private var displayColor: DailyColor {
        if let hex = supabaseFrame?.colorHex {
            return DailyColor.from(hex: hex)
        }
        return viewModel.gridColor(for: date) ?? DailyColorProvider.color(for: date, userSeed: nil)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    Text("Huntone").font(.custom("Comico-Regular", size: 32)).foregroundColor(.black).padding(.bottom, 20)
                    GridTilesView(photos: photos, transforms: transforms, color: displayColor, remoteURLs: remoteImageURLs) { index in
                        selectedTileIndex = index
                    }
                        .padding(.horizontal, 24)
                    Text("— \(displayColor.name.uppercased()) —")
                        .font(.custom("Comico-Regular", size: 32)).foregroundColor(displayColor.swiftUIColor).padding(.top, 16)
                    Spacer().frame(height: 40)
                }
                HStack(spacing: 28) {
                    closeButton; deleteButton; shareButton
                }
                .padding(.top, 24).padding(.bottom, 12)
                Spacer()
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black).frame(width: 32, height: 32)
                    }
                    Spacer()
                }
                .padding(.leading, 20).padding(.top, 56)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            photos = viewModel.fetchPhotos(for: date)
            transforms = viewModel.transforms(for: date)
            if let urls = supabaseFrame?.imageUrls { remoteImageURLs = urls }
            if let caption = supabaseFrame?.caption {
                let parts = caption.components(separatedBy: " - ")
                publishedCity = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : nil
            }
        }
        .sheet(isPresented: $showShareSheet) { if let shareImage { ShareSheet(image: shareImage) } }
        .fullScreenCover(isPresented: Binding(
            get: { selectedTileIndex != nil },
            set: { if !$0 { selectedTileIndex = nil } }
        )) {
            if let index = selectedTileIndex {
                TileFullScreenView(
                    image: photos[index],
                    remoteURL: index < remoteImageURLs.count ? remoteImageURLs[index] : nil,
                    onDismiss: { selectedTileIndex = nil }
                )
            }
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            VStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.black)
                Text(loc("profile.close")).font(.custom("ClashDisplay-Regular", size: 10)).foregroundColor(Color(UIColor.systemGray))
            }
        }
    }

    private var deleteButton: some View {
        Button {
            let dateKey = DailyColorProvider.dateKey(for: date)
            viewModel.deleteGrid(for: date)
            Task {
                try? await supabase.deleteFrame(for: dateKey)
                onDelete?(dateKey)
                dismiss()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "trash.circle.fill").font(.system(size: 28)).foregroundColor(.red)
                Text(loc("profile.delete_grid")).font(.custom("ClashDisplay-Regular", size: 10)).foregroundColor(.red)
            }
        }
    }

    private var shareButton: some View {
        let city = publishedCity
        return Button {
            Task { await prepareAndShare(dailyColor: displayColor, city: city) }
        } label: {
            VStack(spacing: 6) {
                if isLoadingShare { ProgressView().scaleEffect(0.8) }
                else { Image(systemName: "square.and.arrow.up.circle.fill").font(.system(size: 28)).foregroundColor(.black) }
                Text(isLoadingShare ? "..." : loc("profile.share_button")).font(.custom("ClashDisplay-Regular", size: 10))
                    .foregroundColor(Color(UIColor.systemGray))
            }
        }
        .disabled(isLoadingShare)
    }

    private func prepareAndShare(dailyColor: DailyColor, city: String?) async {
        isLoadingShare = true
        var loaded = photos
        let urlsToLoad = remoteImageURLs.enumerated().filter { $0.offset < 9 && loaded[$0.offset] == nil && !$0.element.isEmpty }
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (i, urlStr) in urlsToLoad {
                guard let url = URL(string: urlStr) else { continue }
                group.addTask {
                    var req = URLRequest(url: url)
                    req.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
                    if let (data, _) = try? await URLSession.shared.data(for: req),
                       let img = UIImage(data: data) { return (i, img) }
                    return (i, nil)
                }
            }
            for await (i, img) in group { if let img { loaded[i] = img } }
        }
        let sharePhotos = loaded
        let content = VStack(spacing: 0) {
            Text("Huntone").font(.custom("Comico-Regular", size: 32)).foregroundColor(.black).padding(.bottom, 24)
            GridTilesView(photos: sharePhotos, transforms: transforms, color: dailyColor).padding(.horizontal, 24)
            Text("— \(dailyColor.name.uppercased()) —")
                .font(.custom("Comico-Regular", size: 32)).foregroundColor(dailyColor.swiftUIColor).padding(.top, 16)
            if let city, !city.isEmpty {
                Text(city).font(.custom("Comico-Regular", size: 15))
                    .foregroundColor(Color(UIColor.systemGray)).padding(.top, 6)
            }
        }
        .padding(.vertical, 40)
        let renderer = ImageRenderer(content: content.frame(width: UIScreen.main.bounds.width).background(Color.white))
        renderer.scale = UIScreen.main.scale
        shareImage = renderer.uiImage
        showShareSheet = true
        isLoadingShare = false
    }
}

// MARK: - Grid Tiles View

private struct GridTilesView: View {
    let photos: [UIImage?]
    let transforms: [CellTransform]
    let color: DailyColor
    var remoteURLs: [String] = []
    var onTapIndex: ((Int) -> Void)? = nil

    var body: some View {
        let spacing: CGFloat = 1
        GeometryReader { geo in
            let safeWidth = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width - 48
            let tileW = max(1, (safeWidth - 2) / 3)
            let tileH = tileW * 4 / 3
            VStack(spacing: spacing) {
                ForEach(0..<3) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<3) { col in
                            tileView(row: row, col: col, tileW: tileW, tileH: tileH)
                        }
                    }
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
    }

    private func tileView(row: Int, col: Int, tileW: CGFloat, tileH: CGFloat) -> some View {
        let index = row * 3 + col
        if let image = photos[index] {
            let t = index < transforms.count ? transforms[index] : CellTransform(offsetX: 0, offsetY: 0, scale: 1.0)
            return AnyView(
                Image(uiImage: image).resizable().scaledToFill()
                    .scaleEffect(t.scale)
                    .offset(x: t.offsetX * tileW * (t.scale - 1) / 2, y: t.offsetY * tileH * (t.scale - 1) / 2)
                    .frame(width: tileW, height: tileH).clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { onTapIndex?(index) }
            )
        } else if index < remoteURLs.count, let url = URL(string: remoteURLs[index]) {
            return AnyView(
                SupabaseImage(url: url, fallbackColor: color.swiftUIColor.opacity(0.08))
                    .frame(width: tileW, height: tileH).clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { onTapIndex?(index) }
            )
        } else {
            return AnyView(
                Rectangle().fill(color.swiftUIColor.opacity(0.08))
                    .frame(width: tileW, height: tileH)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapIndex?(index) }
            )
        }
    }
}

// MARK: - Tile Full Screen View

struct TileFullScreenView: View {
    let image: UIImage?
    let remoteURL: String?
    let onDismiss: () -> Void
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else if let remoteURL, let url = URL(string: remoteURL) {
                    SupabaseImage(url: url, fallbackColor: Color.gray.opacity(0.2))
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)

            VStack {
                HStack {
                    Button {
                        savePhoto()
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: showSaved ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(showSaved ? .green : .white)
                        }
                    }
                    .disabled(isSaving)
                    .padding(20)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(20)
                    }
                }
                Spacer()
            }

            if showSaved {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(loc("save.success"))
                            .font(.custom("ClashDisplay-Bold", size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.bottom, 80)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: showSaved)
            }
        }
    }

    private func savePhoto() {
        if let image {
            isSaving = true
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            isSaving = false
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showSaved = false }
        } else if let remoteURL, let url = URL(string: remoteURL) {
            isSaving = true
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        isSaving = false
                        showSaved = true
                    }
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await MainActor.run { showSaved = false }
                } else {
                    await MainActor.run { isSaving = false }
                }
            }
        }
    }
}

// MARK: - Social User Row

private struct SocialUserRow: View {
    let avatarURL: String?
    let username: String
    let subtitle: String
    let showButton: Bool
    var action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if let avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color(UIColor.systemGray6)
                    }
                }
                .frame(width: 48, height: 48).clipShape(Circle())
            } else {
                Circle().fill(Color(UIColor.systemGray6)).frame(width: 48, height: 48)
                    .overlay(
                        Text(String(username.prefix(1)).uppercased())
                            .font(.custom("ClashDisplay-Bold", size: 18)).foregroundColor(.black)
                    )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(username)").font(.custom("ClashDisplay-Bold", size: 16)).foregroundColor(.black)
                Text(subtitle).font(.custom("ClashDisplay-Medium", size: 12)).foregroundColor(Color(UIColor.systemGray))
            }
            Spacer()
            if showButton {
                Button(action: action) {
                    Text(loc("profile.follow_button"))
                        .font(.custom("ClashDisplay-Bold", size: 12))
                        .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.black).clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Incoming Request Row

private struct IncomingRequestRow: View {
    let request: SBFriendship
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Circle().fill(Color(UIColor.systemGray6)).frame(width: 48, height: 48)
                .overlay(
                    Text(String((request.requesterName ?? "?").prefix(1)).uppercased())
                        .font(.custom("ClashDisplay-Bold", size: 18)).foregroundColor(.black)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(request.requesterName ?? "—")
                    .font(.custom("ClashDisplay-Bold", size: 16)).foregroundColor(.black)
                Text(loc("profile.request_pending"))
                    .font(.custom("ClashDisplay-Medium", size: 12)).foregroundColor(Color(UIColor.systemGray))
            }
            Spacer()
            Button(action: onAccept) {
                Text(loc("profile.accept_button"))
                    .font(.custom("ClashDisplay-Bold", size: 12))
                    .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.black).clipShape(Capsule())
            }
        }
    }
}

// MARK: - Stat View

struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.custom("ClashDisplay-Bold", size: 18)).foregroundColor(.black)
            Text(label).font(.custom("ClashDisplay-Medium", size: 12)).foregroundColor(Color(UIColor.systemGray))
        }
    }
}

