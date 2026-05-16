import Foundation
import SwiftData
import UIKit

@Model
final class DailyGrid {
    @Attribute(.unique) var dateKey: String
    var colorHex: String
    @Relationship(deleteRule: .cascade) var cells: [GridCell]

    init(dateKey: String, colorHex: String) {
        self.dateKey = dateKey
        self.colorHex = colorHex
        self.cells = (0..<9).map { GridCell(index: $0) }
    }

    func orderedCells() -> [GridCell] {
        cells.sorted { $0.index < $1.index }
    }
}

@Model
final class GridCell {
    var index: Int
    var imageData: Data?
    /// -1...1, where 0 = centered, -1 = fully left/top, 1 = fully right/bottom
    var offsetFractionX: Double = 0
    var offsetFractionY: Double = 0
    /// ≥1.0, 1.0 = image fills frame exactly
    var scale: Double = 1.0

    init(index: Int) {
        self.index = index
    }

    var uiImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
}
