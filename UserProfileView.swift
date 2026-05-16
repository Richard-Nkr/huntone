import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let username: String

    @State private var profile: SBProfile?
    @State private var frames: [SBFramePost] = []
    @State private var isLoading = true
    @State private var fullScreenFrame: SBFramePost?

    private var isSelf: Bool {
        userId == supabase.currentProfile?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .bottom) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(UIColor.systemGray6))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, 16)

                // Avatar + stats
                HStack(spacing: 20) {
                    if let avatarURL = profile?.avatarURL,
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
                        Circle()
                            .fill(Color.black)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(username.prefix(1).uppercased())
                                    .font(.custom("ClashDisplay-Bold", size: 32))
                                    .foregroundColor(.white)
                            )
                    }

                    HStack(spacing: 24) {
                        StatView(value: "\(frames.count)", label: loc("profile.stats_grids"))
                    }
                    .frame(maxWidth: .infinity)
                }

                // Username
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(username)")
                        .font(.custom("ClashDisplay-Bold", size: 18))
                        .foregroundColor(.black)

                    if let displayName = profile?.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.custom("ClashDisplay-Regular", size: 14))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                }

                // Grids
                if frames.isEmpty && !isLoading {
                    Text(loc("profile.no_grids"))
                        .font(.custom("ClashDisplay-Medium", size: 14))
                        .foregroundColor(Color(UIColor.systemGray))
                        .padding(.top, 24)
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(frames) { frame in
                            UserGridCell(frame: frame)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture { fullScreenFrame = frame }
                        }
                    }
                }
            }
            .padding(24)
            .padding(.bottom, 80)
        }
        .background(Color.white)
        .fullScreenCover(item: $fullScreenFrame) { frame in
            UserFrameFullScreenView(frame: frame)
        }
        .task {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        isLoading = true

        // Fetch profile
        if let (data, _) = try? await supabase.get(path: "/profiles?id=eq.\(userId)&select=*"),
           let profiles = try? JSONDecoder().decode([SBProfile].self, from: data) {
            profile = profiles.first
        }

        // Fetch frames
        if let (data, _) = try? await supabase.get(path: "/frame_posts?owner_id=eq.\(userId)&select=*&order=created_at.desc"),
           let userFrames = try? JSONDecoder().decode([SBFramePost].self, from: data) {
            frames = userFrames
        }

        isLoading = false
    }
}

// MARK: - User Grid Cell (remote images)

private struct UserGridCell: View {
    let frame: SBFramePost

    var body: some View {
        GeometryReader { geo in
            let tileWidth = max(1, geo.size.width / 3)
            VStack(spacing: 0) {
                ForEach(0..<3) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { col in
                            let index = row * 3 + col
                            let fallback = Color(uiColor: UIColor(hex: frame.colorHex)).opacity(0.15)
                            if let urls = frame.imageUrls, index < urls.count,
                               let url = URL(string: urls[index]) {
                                SupabaseImage(url: url, fallbackColor: fallback)
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3)
                                    .clipped()
                            } else {
                                fallback
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - User Frame Full Screen View

private struct UserFrameFullScreenView: View {
    let frame: SBFramePost
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTileIndex: Int?

    private var color: DailyColor {
        DailyColor.from(hex: frame.colorHex)
    }

    private var imageURLs: [String] {
        frame.imageUrls ?? []
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    Text("Huntone")
                        .font(.custom("Comico-Regular", size: 32))
                        .foregroundColor(.black)
                        .padding(.bottom, 20)

                    GeometryReader { geo in
                        let safeWidth = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width - 48
                        let tileW = max(1, (safeWidth - 2) / 3)
                        let tileH = tileW * 4 / 3
                        VStack(spacing: 1) {
                            ForEach(0..<3) { row in
                                HStack(spacing: 1) {
                                    ForEach(0..<3) { col in
                                        let index = row * 3 + col
                                        if index < imageURLs.count, let url = URL(string: imageURLs[index]) {
                                            SupabaseImage(url: url, fallbackColor: color.swiftUIColor.opacity(0.08))
                                                .frame(width: tileW, height: tileH)
                                                .clipped()
                                                .contentShape(Rectangle())
                                                .onTapGesture { selectedTileIndex = index }
                                        } else {
                                            color.swiftUIColor.opacity(0.08)
                                                .frame(width: tileW, height: tileH)
                                                .contentShape(Rectangle())
                                                .onTapGesture { selectedTileIndex = index }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .padding(.horizontal, 24)

                    Text("— \(color.name.uppercased()) —")
                        .font(.custom("Comico-Regular", size: 32))
                        .foregroundColor(color.swiftUIColor)
                        .padding(.top, 16)
                    Spacer().frame(height: 40)
                }

                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 56)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: Binding(
            get: { selectedTileIndex != nil },
            set: { if !$0 { selectedTileIndex = nil } }
        )) {
            if let index = selectedTileIndex, index < imageURLs.count {
                TileFullScreenView(
                    image: nil,
                    remoteURL: imageURLs[index],
                    onDismiss: { selectedTileIndex = nil }
                )
            }
        }
    }
}

#Preview {
    UserProfileView(userId: "sample", username: "test")
        .environmentObject(SupabaseService.shared)
}
