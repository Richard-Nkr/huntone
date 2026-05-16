import SwiftUI

struct SupabaseImage: View {
    let url: URL
    let fallbackColor: Color

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                fallbackColor
                    .overlay(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear, .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: loadedImage != nil)
        .task {
            var req = URLRequest(url: url)
            req.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                if let img = UIImage(data: data) {
                    loadedImage = img
                }
            } catch {}
        }
    }
}
