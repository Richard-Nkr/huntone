import SwiftUI

struct GridCellView: View {
    @EnvironmentObject private var viewModel: HuntoneViewModel
    let index: Int
    let tint: Color
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            if let image = viewModel.photos[index] {
                let scale = viewModel.cellScale(for: index)
                let maxOffsetX = geo.size.width * (scale - 1) / 2
                let maxOffsetY = geo.size.height * (scale - 1) / 2
                let displayOffsetX = viewModel.cellOffsetFractionX(for: index) * maxOffsetX
                let displayOffsetY = viewModel.cellOffsetFractionY(for: index) * maxOffsetY

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(x: displayOffsetX, y: displayOffsetY)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                EmptyCellView(tint: tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .overlay(
            Group {
                if isSelected {
                    Rectangle()
                        .stroke(Color.black, lineWidth: 2)
                }
            }
        )
    }
}

private struct EmptyCellView: View {
    let tint: Color

    var body: some View {
        Rectangle()
            .fill(tint.opacity(0.08))
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(tint.opacity(0.4))
            )
    }
}
