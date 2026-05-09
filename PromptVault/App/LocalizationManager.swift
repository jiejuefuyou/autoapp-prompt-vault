import Foundation
import SwiftUI

/// Centralized language override for the in-app language picker.
///
/// SwiftUI applies the chosen locale immediately via `.environment(\.locale, ...)`.
/// `AppleLanguages` is also written so any UIKit-bridged code (alerts, system pickers)
/// uses the same language on the *next* launch.
@Observable
final class LocalizationManager {

    static let shared = LocalizationManager()

    /// Supported BCP-47 codes shipped with the app, in display order.
    static let supportedLanguages: [String] = [
        "en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"
    ]

    /// Empty string ("") means "follow system default".
    private let storageKey = "appLanguageOverride"

    /// Current override; "" follows system.
    var override: String {
        didSet { persist() }
    }

    /// The `Locale` that should be passed into `.environment(\.locale, ...)`.
    var currentLocale: Locale {
        if override.isEmpty {
            return .current
        }
        return Locale(identifier: override)
    }

    private init() {
        self.override = UserDefaults.standard.string(forKey: storageKey) ?? ""
        applyAppleLanguages(override)
    }

    func setOverride(_ code: String) {
        let normalized = Self.supportedLanguages.contains(code) ? code : ""
        override = normalized
        applyAppleLanguages(normalized)
    }

    private func persist() {
        UserDefaults.standard.set(override, forKey: storageKey)
    }

    private func applyAppleLanguages(_ code: String) {
        let defaults = UserDefaults.standard
        if code.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([code], forKey: "AppleLanguages")
        }
    }

    static func displayName(for code: String) -> String {
        if code.isEmpty {
            return String(localized: "System default")
        }
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized
            ?? Locale.current.localizedString(forLanguageCode: code)
            ?? code
    }
}
