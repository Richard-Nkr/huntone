import SwiftUI

struct FeedPost: Identifiable {
    let id: UUID
    let authorName: String
    let handle: String
    let location: String
    let timeAgo: String
    let color: DailyColor
    let caption: String
    let likes: Int
    let tiles: [FeedTile]

    static let samples: [FeedPost] = [
        FeedPost(
            id: UUID(),
            authorName: "Maya",
            handle: "@maya.moves",
            location: "Lisbonne",
            timeAgo: "12 min",
            color: DailyColor(id: "azulejo", name: "Cobalt", hex: "#2667FF"),
            caption: "Neuf bleus trouves entre Alfama et le Tage.",
            likes: 248,
            tiles: FeedTile.makePalette(base: "#2667FF", accents: ["#6EA8FF", "#173B8F", "#9DD6FF", "#FFFFFF"])
        ),
        FeedPost(
            id: UUID(),
            authorName: "Noah",
            handle: "@noah.walks",
            location: "Kyoto",
            timeAgo: "34 min",
            color: DailyColor(id: "moss-feed", name: "Mousse", hex: "#5B8C5A"),
            caption: "Le vert etait partout des jardins aux vitrines.",
            likes: 513,
            tiles: FeedTile.makePalette(base: "#5B8C5A", accents: ["#A7C957", "#31572C", "#ECF39E", "#DAD7CD"])
        ),
        FeedPost(
            id: UUID(),
            authorName: "Ines",
            handle: "@ines.nomad",
            location: "Marrakech",
            timeAgo: "1 h",
            color: DailyColor(id: "terracotta-feed", name: "Terracotta", hex: "#C86B4A"),
            caption: "Une marche chaude, poussiereuse, parfaite.",
            likes: 391,
            tiles: FeedTile.makePalette(base: "#C86B4A", accents: ["#F2A65A", "#8A3B2F", "#FFD6A5", "#6B705C"])
        )
    ]
}

struct FeedTile: Identifiable {
    let id = UUID()
    let colors: [Color]
    let symbolName: String

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
}
