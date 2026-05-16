import SwiftUI
import UIKit

struct DailyColor: Identifiable, Equatable {
    let id: String
    let name: String
    let hex: String

    static func from(hex: String) -> DailyColor {
        if let match = DailyColorProvider.palette.first(where: { $0.hex.uppercased() == hex.uppercased() }) {
            return match
        }
        let name = DailyColorProvider.nameFrom(hex: hex)
        return DailyColor(id: name.lowercased().replacingOccurrences(of: " ", with: "-"), name: name, hex: hex)
    }

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
    private static let overrides: [String: DailyColor] = [
        "2026-05-12": DailyColor(id: "rouge", name: "Rouge", hex: "#E63946"),
    ]

    static let palette: [DailyColor] = [
        DailyColor(id: "rouge",    name: "Rouge",    hex: "#E63946"),
        DailyColor(id: "orange",   name: "Orange",   hex: "#F4A261"),
        DailyColor(id: "jaune",    name: "Jaune",    hex: "#E9C46A"),
        DailyColor(id: "vert",     name: "Vert",     hex: "#2A9D8F"),
        DailyColor(id: "bleu",     name: "Bleu",     hex: "#264653"),
        DailyColor(id: "violet",   name: "Violet",   hex: "#9B5DE5"),
        DailyColor(id: "rose",     name: "Rose",     hex: "#F15BB5"),
        DailyColor(id: "cyan",     name: "Cyan",     hex: "#00BBF9"),
        DailyColor(id: "marron",   name: "Marron",   hex: "#8B5A2B"),
        DailyColor(id: "menthe",   name: "Menthe",   hex: "#06D6A0"),
        DailyColor(id: "corail",   name: "Corail",   hex: "#FF6B6B"),
        DailyColor(id: "indigo",   name: "Indigo",   hex: "#3A0CA3"),
    ]

    @MainActor
    static func color(for date: Date = Date(), userSeed: String? = nil) -> DailyColor {
        let dateKey = Self.dateKey(for: date)
        if let override = overrides[dateKey] { return override }
        let seed = userSeed ?? dateKey
        let fullText = "\(dateKey)|\(seed)"

        let h = Double(deterministicHash(fullText) % 360)
        let s = 45 + Double(deterministicHash("\(fullText)-s") % 45)
        let l = 30 + Double(deterministicHash("\(fullText)-l") % 50)

        let hex = hexFrom(h: h, s: s, l: l)
        let name = nameFrom(hue: h, saturation: s, lightness: l)
        return DailyColor(id: name.lowercased().replacingOccurrences(of: " ", with: "-"), name: name, hex: hex)
    }

    static func nameFrom(hex: String) -> String {
        let (h, s, l) = hslFrom(hex: hex)
        return nameFrom(hue: h, saturation: s, lightness: l)
    }

    static func dateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Color name generation

    private static func nameFrom(hue: Double, saturation: Double, lightness: Double) -> String {
        let family = hueFamily(hue)
        if lightness < 35 { return "\(family) sombre" }
        if saturation < 45 { return "\(family) doux" }
        if lightness > 70 { return "\(family) pâle" }
        if saturation > 80 { return "\(family) vif" }
        return family
    }

    private static func hueFamily(_ hue: Double) -> String {
        switch hue {
        case 0..<12:   return "Rouge"
        case 12..<25:  return "Vermillon"
        case 25..<40:  return "Orange"
        case 40..<55:  return "Ambre"
        case 55..<70:  return "Jaune"
        case 70..<85:  return "Chartreuse"
        case 85..<110: return "Vert"
        case 110..<130: return "Émeraude"
        case 130..<155: return "Menthe"
        case 155..<170: return "Turquoise"
        case 170..<195: return "Cyan"
        case 195..<210: return "Céruléen"
        case 210..<230: return "Bleu"
        case 230..<250: return "Azur"
        case 250..<270: return "Indigo"
        case 270..<290: return "Violet"
        case 290..<310: return "Magenta"
        case 310..<335: return "Rose"
        case 335..<350: return "Corail"
        default:        return "Rouge"
        }
    }

    // MARK: - HSL ↔ RGB ↔ Hex

    private static func hexFrom(h: Double, s: Double, l: Double) -> String {
        let (r, g, b) = hslToRgb(h: h, s: s / 100, l: l / 100)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private static func hslFrom(hex: String) -> (h: Double, s: Double, l: Double) {
        let (r, g, b) = rgbFrom(hex: hex)
        let rf = r / 255
        let gf = g / 255
        let bf = b / 255
        let maxV = max(rf, gf, bf)
        let minV = min(rf, gf, bf)
        let delta = maxV - minV
        let l = (maxV + minV) / 2

        if delta == 0 { return (0, 0, l * 100) }
        let s = l > 0.5 ? delta / (2 - maxV - minV) : delta / (maxV + minV)
        let h: Double
        switch maxV {
        case rf: h = (60 * ((gf - bf) / delta) + 360).truncatingRemainder(dividingBy: 360)
        case gf: h = (60 * ((bf - rf) / delta) + 120).truncatingRemainder(dividingBy: 360)
        default: h = (60 * ((rf - gf) / delta) + 240).truncatingRemainder(dividingBy: 360)
        }
        return (h, s * 100, l * 100)
    }

    private static func rgbFrom(hex: String) -> (r: Double, g: Double, b: Double) {
        let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        return (Double((value & 0xFF0000) >> 16), Double((value & 0x00FF00) >> 8), Double(value & 0x0000FF))
    }

    private static func hslToRgb(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double)
        switch floor(h / 60) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return (r + m, g + m, b + m)
    }

    // MARK: - Hashing

    private static func deterministicHash(_ text: String) -> UInt {
        text.unicodeScalars.reduce(5381) { partialResult, scalar in
            ((partialResult << 5) &+ partialResult) &+ UInt(scalar.value)
        }
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
