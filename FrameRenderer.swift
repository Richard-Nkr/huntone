import UIKit

enum FrameRenderer {
    static func render(photos: [UIImage?], dailyColor: DailyColor, size: CGSize = CGSize(width: 1080, height: 1350)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.black.setFill()
            context.fill(rect)

            let margin: CGFloat = 36
            let gap: CGFloat = 6
            let titleHeight: CGFloat = 160
            let gridTop = margin + titleHeight
            let tileHeight = (size.height - gridTop - margin - (gap * 2)) / 3
            let tileWidth = tileHeight * 4 / 5
            let gridLeft = (size.width - (tileWidth * 3) - (gap * 2)) / 2

            drawHeader(in: CGRect(x: margin, y: margin, width: size.width - margin * 2, height: titleHeight), dailyColor: dailyColor)

            for index in 0..<9 {
                let row = index / 3
                let column = index % 3
                let tileRect = CGRect(
                    x: gridLeft + CGFloat(column) * (tileWidth + gap),
                    y: gridTop + CGFloat(row) * (tileHeight + gap),
                    width: tileWidth,
                    height: tileHeight
                )

                drawTile(image: photos[safe: index] ?? nil, in: tileRect, fallbackColor: dailyColor.uiColor)
            }
        }
    }

    private static func drawHeader(in rect: CGRect, dailyColor: DailyColor) {
        let swatchRect = CGRect(x: rect.minX, y: rect.minY + 20, width: 100, height: 100)
        dailyColor.uiColor.setFill()
        UIRectFill(swatchRect)

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.lightGray
        ]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 64, weight: .black),
            .foregroundColor: UIColor.white
        ]
        let hexAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .regular),
            .foregroundColor: UIColor.lightGray
        ]

        "COULEUR DU JOUR".draw(at: CGPoint(x: swatchRect.maxX + 32, y: rect.minY + 20), withAttributes: subtitleAttributes)
        dailyColor.name.uppercased().draw(at: CGPoint(x: swatchRect.maxX + 32, y: rect.minY + 48), withAttributes: titleAttributes)
        dailyColor.hex.draw(at: CGPoint(x: swatchRect.maxX + 32, y: rect.minY + 120 - 32), withAttributes: hexAttributes)
    }

    private static func drawTile(image: UIImage?, in rect: CGRect, fallbackColor: UIColor) {
        let path = UIBezierPath(rect: rect)
        contextSaveGState()
        path.addClip()

        if let image {
            image.drawAspectFill(in: rect)
        } else {
            UIColor(white: 0.15, alpha: 1).setFill()
            UIRectFill(rect)
        }
        
        contextRestoreGState()
    }
    
    private static func contextSaveGState() {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
    }
    
    private static func contextRestoreGState() {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
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
