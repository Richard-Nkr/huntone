import SwiftUI

func loc(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var current: String {
        didSet {
            UserDefaults.standard.set([current], forKey: "AppleLanguages")
        }
    }

    private init() {
        current = Locale.preferredLanguages.first?.prefix(2).lowercased() == "fr" ? "fr" : "en"
        object_setClass(Bundle.main, LocalizedBundle.self)
    }

    func toggle() {
        current = current == "fr" ? "en" : "fr"
        object_setClass(Bundle.main, LocalizedBundle.self)
    }
}

private class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = Bundle.main.path(forResource: LanguageManager.shared.current, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
