import SwiftUI
import UIKit

struct DailyColor: Identifiable, Equatable {
    let id: String
    let name: String
    let hex: String

    var swiftUIColor: Color {
        Color(uiColor)
    }

    var uiColor: UIColor {
        UIColor(hex: hex)
    }

    var accessibilityLabel: String {
        "\(name), \(hex)"
    }
}

enum DailyColorProvider {
    static let palette: [DailyColor] = [
        DailyColor(id: "tomato", name: "Tomate", hex: "#E94F37"),
        DailyColor(id: "sunflower", name: "Tournesol", hex: "#F6C945"),
        DailyColor(id: "moss", name: "Mousse", hex: "#5B8C5A"),
        DailyColor(id: "lagoon", name: "Lagon", hex: "#2A9D8F"),
        DailyColor(id: "sky", name: "Ciel", hex: "#4EA8DE"),
        DailyColor(id: "indigo", name: "Indigo", hex: "#4B5DFF"),
        DailyColor(id: "orchid", name: "Orchidee", hex: "#B565A7"),
        DailyColor(id: "coral", name: "Corail", hex: "#FF7A70"),
        DailyColor(id: "terracotta", name: "Terracotta", hex: "#C86B4A"),
        DailyColor(id: "mint", name: "Menthe", hex: "#74C69D"),
        DailyColor(id: "cobalt", name: "Cobalt", hex: "#2667FF"),
        DailyColor(id: "plum", name: "Prune", hex: "#6D597A")
    ]

    static func color(for date: Date = Date(), userDefaults: UserDefaults = .standard) -> DailyColor {
        let installSeed = userDefaults.installSeed
        let dateKey = Self.dateKey(for: date)
        let value = deterministicHash("\(dateKey)-\(installSeed)")
        let index = Int(value % UInt(palette.count))
        return palette[index]
    }

    static func dateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func deterministicHash(_ text: String) -> UInt {
        text.unicodeScalars.reduce(5381) { partialResult, scalar in
            ((partialResult << 5) &+ partialResult) &+ UInt(scalar.value)
        }
    }
}

private extension UserDefaults {
    var installSeed: String {
        let key = "huntone.installSeed"
        if let existing = string(forKey: key) {
            return existing
        }

        let newValue = UUID().uuidString
        set(newValue, forKey: key)
        return newValue
    }
}

extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
