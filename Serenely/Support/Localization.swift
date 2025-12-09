import Foundation
import Combine

enum AppLanguage: String, CaseIterable {
    case uk = "uk"
    case en = "en"
}

enum L10n {
    private static let langKey = "app_language"

    static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: langKey), let l = AppLanguage(rawValue: raw) {
                return l
            }
            // Derive from system preferred languages
            let pref = Locale.preferredLanguages.first ?? "en"
            if pref.lowercased().hasPrefix("uk") { return .uk }
            return .en
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: langKey) }
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }

    static func t(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle(for: current), value: fallback, comment: "")
    }
}

final class LocalizationManager: ObservableObject {
    @Published var language: AppLanguage

    init() {
        self.language = L10n.current
    }

    func set(_ lang: AppLanguage) {
        guard lang != language else { return }
        L10n.current = lang
        language = lang
    }
}





