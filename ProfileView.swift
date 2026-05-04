import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    
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
            
            Text("\(viewModel.availableDates.count) JOURS")
                .font(.custom("ClashDisplay-Medium", size: 10))
                .foregroundColor(Color(UIColor.systemGray))
        }
        .padding(.top, 24)
    }
}

private struct HistoryGrid: View {
    let date: Date
    @EnvironmentObject private var viewModel: HuntoneViewModel
    @State private var photos: [UIImage?] = Array(repeating: nil, count: 9)
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let color = DailyColorProvider.color(for: date)
            
            HStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 16, height: 16)
                
                Text(DailyColorProvider.dateKey(for: date))
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
