import SwiftUI

struct UserProfileSheet: Identifiable {
    let id: String
    let username: String
}

struct FeedView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var fullScreenPost: FeedPost?
    @State private var selectedUserId: String?
    @State private var selectedUsername: String?

    private var posts: [FeedPost] {
        supabase.feedFrames.map { FeedPost(from: $0) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 8)
                if posts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer().frame(height: 80)
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 48))
                            .foregroundColor(Color(UIColor.systemGray4))
                        Text(loc("feed.empty"))
                            .font(.custom("ClashDisplay-Medium", size: 14))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                    .frame(maxWidth: .infinity)
                }
                ForEach(posts) { post in
                    FeedPostCard(post: post, onTapGrid: {
                        fullScreenPost = post
                    }, onTapShare: {
                        fullScreenPost = post
                    }, onTapUser: {
                        selectedUserId = post.ownerId
                        selectedUsername = String(post.handle.dropFirst())
                    })
                    .padding(.horizontal, 16)
                }
                Color.clear.frame(height: 16)
            }
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .refreshable {
            _ = try? await supabase.fetchLatestFrames()
        }
        .fullScreenCover(item: $fullScreenPost) { post in
            GridFullScreenView(post: post)
        }
        .sheet(item: Binding(
            get: { selectedUserId.map { UserProfileSheet(id: $0, username: selectedUsername ?? "") } },
            set: { _ in selectedUserId = nil }
        )) { sheet in
            UserProfileView(userId: sheet.id, username: sheet.username)
                .environmentObject(supabase)
        }
        .task {
            _ = try? await supabase.fetchLatestFrames()
        }
        .onAppear {
            Task { try? await supabase.fetchLatestFrames() }
        }
    }
}

private struct FeedPostCard: View {
    let post: FeedPost
    var onTapGrid: (() -> Void)?
    var onTapShare: (() -> Void)?
    var onTapUser: (() -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton

            Text("— \(post.color.name.uppercased()) —")
                .font(.custom("Comico-Regular", size: 22))
                .foregroundColor(post.color.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(post.tiles) { tile in
                    FeedTileView(tile: tile)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .clipped()
                }
            }
            .onTapGesture { onTapGrid?() }

            HStack {
                Spacer()
                Button { onTapShare?() } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            Divider()
        }
        .padding(.vertical, 16)
    }

    private var headerButton: some View {
        Button { onTapUser?() } label: {
            HStack(alignment: .center, spacing: 10) {
                if let avatarURL = post.avatarURL, !avatarURL.isEmpty,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color(UIColor.systemGray5)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(post.handle.prefix(1)).uppercased())
                                .font(.custom("ClashDisplay-Bold", size: 14))
                                .foregroundColor(.black)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.handle.replacingOccurrences(of: "@", with: ""))
                        .font(.custom("ClashDisplay-Bold", size: 14))
                        .foregroundColor(.black)

                    HStack(spacing: 4) {
                        Text(post.city)
                            .font(.custom("ClashDisplay-Regular", size: 12))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                }

                Spacer()

                Text(post.timeAgo)
                    .font(.custom("ClashDisplay-Regular", size: 12))
                    .foregroundColor(Color(UIColor.systemGray))
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }
}

private struct FeedTileView: View {
    let tile: FeedTile

    var body: some View {
        GeometryReader { geo in
            if let urlString = tile.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        let s = tile.scale
                        let maxOffsetX = geo.size.width * (s - 1) / 2
                        let maxOffsetY = geo.size.height * (s - 1) / 2
                        image
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(s)
                            .offset(x: tile.offsetX * maxOffsetX, y: tile.offsetY * maxOffsetY)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    case .failure:
                        fallbackGradient
                    case .empty:
                        fallbackGradient
                    @unknown default:
                        fallbackGradient
                    }
                }
            } else {
                fallbackGradient
            }
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(colors: tile.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct GridFullScreenView: View {
    let post: FeedPost
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var loadedImages: [UIImage?] = Array(repeating: nil, count: 9)
    @State private var isLoadingShare = false
    @State private var selectedTileIndex: Int?
    private let gridSpacing: CGFloat = 1

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                shareableContent

                HStack(spacing: 28) {
                    Button {
                        Task { await prepareShareImage() }
                    } label: {
                        VStack(spacing: 6) {
                            if isLoadingShare {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                            }
                            Text(loc("profile.share_button"))
                                .font(.custom("ClashDisplay-Regular", size: 10))
                        }
                        .foregroundColor(.black)
                    }
                    .disabled(isLoadingShare)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)

                Spacer()
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 56)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .task {
            await loadAllImages()
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ShareSheet(image: shareImage)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedTileIndex != nil },
            set: { if !$0 { selectedTileIndex = nil } }
        )) {
            if let index = selectedTileIndex, index < post.tiles.count {
                FeedTileFullScreenView(
                    post: post,
                    tileIndex: index,
                    loadedImages: loadedImages,
                    onDismiss: { selectedTileIndex = nil }
                )
            }
        }
    }

    private func loadAllImages() async {
        for (index, tile) in post.tiles.enumerated() {
            guard let urlString = tile.imageURL, let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                loadedImages[index] = UIImage(data: data)
            } catch {
                print("❌ Failed to load image \(index): \(error)")
            }
        }
    }

    private func prepareShareImage() async {
        isLoadingShare = true
        await loadAllImages()
        let content = renderedShareContent
            .frame(width: UIScreen.main.bounds.width)
            .background(Color.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            showShareSheet = true
        }
        isLoadingShare = false
    }

    private var renderedShareContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            Text("Huntone")
                .font(.custom("Comico-Regular", size: 32))
                .foregroundColor(.black)
                .padding(.bottom, 20)
            ShareGridTilesView(
                tiles: post.tiles,
                loadedImages: loadedImages,
                fallbackColor: post.color,
                gridSpacing: gridSpacing
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding(.horizontal, 24)
            Text("— \(post.color.name.uppercased()) —")
                .font(.custom("Comico-Regular", size: 32))
                .foregroundColor(post.color.swiftUIColor)
                .padding(.top, 16)
            if !post.city.isEmpty && post.city != loc("feed.unknown_location") {
                Text(post.city)
                    .font(.custom("Comico-Regular", size: 15))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.top, 6)
            }
            Spacer().frame(height: 40)
        }
    }

    private var shareableContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            Text("Huntone")
                .font(.custom("Comico-Regular", size: 32))
                .foregroundColor(.black)
                .padding(.bottom, 20)
            GeometryReader { geo in
                let safeWidth = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width - 48
                let tileWidth = max(1, (safeWidth - gridSpacing * 2) / 3)
                VStack(spacing: gridSpacing) {
                    ForEach(0..<3) { row in
                        HStack(spacing: gridSpacing) {
                            ForEach(0..<3) { col in
                                FeedTileView(tile: post.tiles[row * 3 + col])
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTileIndex = row * 3 + col }
                            }
                        }
                    }
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding(.horizontal, 24)
            Text("— \(post.color.name.uppercased()) —")
                .font(.custom("Comico-Regular", size: 32))
                .foregroundColor(post.color.swiftUIColor)
                .padding(.top, 16)
            if !post.city.isEmpty && post.city != loc("feed.unknown_location") {
                Text(post.city)
                    .font(.custom("Comico-Regular", size: 15))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.top, 6)
            }
            Spacer().frame(height: 40)
        }
    }

    private func shareButton(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.black)
            Text(label)
                .font(.custom("ClashDisplay-Regular", size: 10))
                .foregroundColor(Color(UIColor.systemGray))
        }
    }
}

private struct ShareGridTilesView: View {
    let tiles: [FeedTile]
    let loadedImages: [UIImage?]
    let fallbackColor: DailyColor
    let gridSpacing: CGFloat

    var body: some View {
        GeometryReader { geo in
            let safeWidth = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width - 48
            let tileWidth = max(1, (safeWidth - gridSpacing * 2) / 3)
            let tileHeight = tileWidth * 4 / 3
            VStack(spacing: gridSpacing) {
                ForEach(0..<3) { row in
                    HStack(spacing: gridSpacing) {
                        ForEach(0..<3) { col in
                            let index = row * 3 + col
                            if index < tiles.count, let image = loadedImages[index] {
                                let tile = tiles[index]
                                let s = tile.scale
                                let maxOffsetX = tileWidth * (s - 1) / 2
                                let maxOffsetY = tileHeight * (s - 1) / 2
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .scaleEffect(s)
                                    .offset(x: tile.offsetX * maxOffsetX, y: tile.offsetY * maxOffsetY)
                                    .frame(width: tileWidth, height: tileHeight)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(fallbackColor.swiftUIColor.opacity(0.08))
                                    .frame(width: tileWidth, height: tileHeight)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FeedTileFullScreenView: View {
    let post: FeedPost
    let tileIndex: Int
    let loadedImages: [UIImage?]
    let onDismiss: () -> Void
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        let tile = post.tiles[tileIndex]
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if tileIndex < loadedImages.count, let image = loadedImages[tileIndex] {
                    Image(uiImage: image).resizable().scaledToFit()
                } else if let urlString = tile.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            fallbackGradient(for: tile)
                        }
                    }
                } else {
                    fallbackGradient(for: tile)
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
                    Button { onDismiss() } label: {
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
            }
        }
    }

    private func savePhoto() {
        let tile = post.tiles[tileIndex]
        if tileIndex < loadedImages.count, let image = loadedImages[tileIndex] {
            isSaving = true
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            isSaving = false
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showSaved = false }
        } else if let urlString = tile.imageURL, let url = URL(string: urlString) {
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

    private func fallbackGradient(for tile: FeedTile) -> some View {
        LinearGradient(colors: tile.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
