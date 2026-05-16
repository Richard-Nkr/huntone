import UIKit

enum FrameRenderer {
    static func render(photos: [UIImage?], dailyColor: DailyColor, size: CGSize = CGSize(width: 1080, height: 1440)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.black.setFill()
            context.fill(rect)

            let tileWidth = size.width / 3
            let tileHeight = tileWidth * 4 / 3

            for index in 0..<9 {
                let row = index / 3
                let column = index % 3
                let tileRect = CGRect(
                    x: CGFloat(column) * tileWidth,
                    y: CGFloat(row) * tileHeight,
                    width: tileWidth,
                    height: tileHeight
                )

                drawTile(image: photos[safe: index] ?? nil, in: tileRect, fallbackColor: dailyColor.uiColor)
            }
        }
    }

    private static func drawTile(image: UIImage?, in rect: CGRect, fallbackColor: UIColor) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()

        let path = UIBezierPath(rect: rect)
        path.addClip()

        if let image {
            image.drawAspectFill(in: rect)
        } else {
            fallbackColor.withAlphaComponent(0.15).setFill()
            UIRectFill(rect)
        }

        ctx.restoreGState()
    }
}

private extension UIImage {
    func drawAspectFill(in rect: CGRect) {
        let widthRatio = rect.width / size.width
        let heightRatio = rect.height / size.height
        let scale = max(widthRatio, heightRatio)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let drawOrigin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        draw(in: CGRect(origin: drawOrigin, size: drawSize))
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
