import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel

    private let posts = FeedPost.samples

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        FeedPostCard(post: post)
                            .padding(.horizontal, 24)
                            .containerRelativeFrame(.vertical)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .background(Color.white)
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .overlay(alignment: .top) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .background(
                        Color.white
                            .opacity(0.9)
                            .mask(LinearGradient(gradient: Gradient(colors: [.white, .white, .clear]), startPoint: .top, endPoint: .bottom))
                            .padding(.bottom, -20)
                    )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Huntone")
                .font(.custom("ClashDisplay-Bold", size: 28))
                .foregroundColor(.black)
            
            Spacer()

            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TODAY")
                        .font(.custom("ClashDisplay-Medium", size: 10))
                        .foregroundColor(Color(UIColor.systemGray))
                    Text(viewModel.dailyColor.name.uppercased())
                        .font(.custom("ClashDisplay-Bold", size: 12))
                        .foregroundColor(.black)
                }
                
                Rectangle()
                    .fill(viewModel.dailyColor.swiftUIColor)
                    .frame(width: 24, height: 24)
            }
        }
    }
}

private struct FeedPostCard: View {
    let post: FeedPost

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(post.handle.replacingOccurrences(of: "@", with: ""))
                    .font(.custom("ClashDisplay-Medium", size: 14))
                    .foregroundColor(.black)
                Text("·")
                    .font(.custom("ClashDisplay-Regular", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
                Text(post.timeAgo)
                    .font(.custom("ClashDisplay-Regular", size: 14))
                    .foregroundColor(Color(UIColor.systemGray))
            }

            Text(post.caption)
                .font(.custom("ClashDisplay-Regular", size: 16))
                .foregroundColor(.black)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(post.tiles) { tile in
                    FeedTileView(tile: tile)
                }
            }

            HStack(spacing: 18) {
                Label("\(post.likes)", systemImage: "heart")
                Label("Commenter", systemImage: "bubble.right")
                Label("Partager", systemImage: "paperplane")
                Spacer()
                Image(systemName: "bookmark")
            }
            .font(.custom("ClashDisplay-Medium", size: 14))
            .foregroundColor(.black)
            .padding(.top, 4)
        }
    }
}

private struct FeedTileView: View {
    let tile: FeedTile

    var body: some View {
        ZStack {
            LinearGradient(colors: tile.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipped()
    }
}
