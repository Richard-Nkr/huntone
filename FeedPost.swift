import SwiftUI

struct FeedPost: Identifiable {
    let id: UUID
    let ownerId: String
    let authorName: String
    let handle: String
    let city: String
    let location: String
    let timeAgo: String
    let device: String
    let color: DailyColor
    let caption: String
    let likes: Int
    let tiles: [FeedTile]
    let avatarURL: String?

    init(
        id: UUID,
        ownerId: String,
        authorName: String,
        handle: String,
        city: String,
        location: String,
        timeAgo: String,
        device: String,
        color: DailyColor,
        caption: String,
        likes: Int,
        tiles: [FeedTile],
        avatarURL: String? = nil
    ) {
        self.id = id
        self.ownerId = ownerId
        self.authorName = authorName
        self.handle = handle
        self.city = city
        self.location = location
        self.timeAgo = timeAgo
        self.device = device
        self.color = color
        self.caption = caption
        self.likes = likes
        self.tiles = tiles
        self.avatarURL = avatarURL
    }

    init(from frame: SBFramePost) {
        let captionParts = frame.caption.components(separatedBy: " - ")
        let city = captionParts.count > 1 ? captionParts.dropFirst().joined(separator: " - ") : ""
        let dailyColor = DailyColor.from(hex: frame.colorHex)
        let timeAgo = Self.formatTimeAgo(frame.createdAt)

        self.id = UUID()
        self.ownerId = frame.ownerId
        self.authorName = frame.ownerName
        self.handle = "@\(frame.ownerName.lowercased().replacingOccurrences(of: " ", with: "."))"
        self.city = city.isEmpty ? loc("feed.unknown_location") : city
        self.location = self.city
        self.timeAgo = timeAgo
        self.device = "Huntone"
        self.color = dailyColor
        self.caption = frame.caption
        self.likes = frame.likesCount ?? 0
        self.avatarURL = frame.ownerAvatarURL
        self.tiles = (frame.imageUrls?.isEmpty == false)
            ? FeedTile.fromURLs(frame.imageUrls!, fallbackColor: frame.colorHex, transforms: frame.imageTransforms ?? [])
            : FeedTile.makePalette(
                base: frame.colorHex,
                accents: [frame.colorHex, frame.colorHex, frame.colorHex, frame.colorHex]
            )
    }

    private static func formatTimeAgo(_ isoDate: String?) -> String {
        guard let isoDate, let date = ISO8601DateFormatter().date(from: isoDate) else {
            return ""
        }
        let interval = -date.timeIntervalSinceNow
        switch interval {
        case ..<60: return loc("time.just_now")
        case ..<3600: return String(format: loc("time.minutes"), Int(interval / 60))
        case ..<86400: return String(format: loc("time.hours"), Int(interval / 3600))
        default: return String(format: loc("time.days"), Int(interval / 86400))
        }
    }
}

struct FeedTile: Identifiable {
    let id = UUID()
    let colors: [Color]
    let symbolName: String
    let imageURL: String?
    let offsetX: Double
    let offsetY: Double
    let scale: Double

    init(colors: [Color], symbolName: String = "", imageURL: String? = nil, offsetX: Double = 0, offsetY: Double = 0, scale: Double = 1.0) {
        self.colors = colors
        self.symbolName = symbolName
        self.imageURL = imageURL
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
    }

    static func makePalette(base: String, accents: [String]) -> [FeedTile] {
        let palette = ([base] + accents).map { Color(uiColor: UIColor(hex: $0)) }

        return (0..<9).map { index in
            FeedTile(
                colors: [
                    palette[index % palette.count],
                    palette[(index + 2) % palette.count]
                ],
                symbolName: ""
            )
        }
    }

    static func fromURLs(_ urls: [String], fallbackColor: String, transforms: [SBImageTransform] = []) -> [FeedTile] {
        let palette = [fallbackColor, fallbackColor, fallbackColor, fallbackColor, fallbackColor]
            .map { Color(uiColor: UIColor(hex: $0)) }

        return (0..<9).map { index in
            let t = index < transforms.count ? transforms[index] : nil
            if index < urls.count {
                return FeedTile(colors: palette, imageURL: urls[index],
                         offsetX: t?.ox ?? 0, offsetY: t?.oy ?? 0, scale: t?.scale ?? 1.0)
            } else {
                return FeedTile(colors: [palette[index % palette.count], palette[(index + 2) % palette.count]])
            }
        }
    }
}