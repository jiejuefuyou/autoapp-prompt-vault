import Foundation
import SwiftUI
import ObjectiveC.runtime

/// Subclass of `Bundle` that resolves `localizedString` against an in-app
/// language override. iOS resolves strings via `Bundle.main.localizedString`,
/// which honors `AppleLanguages` UserDefaults set at launch — but ignores the
/// SwiftUI `.environment(\.locale)` for resource lookup. That's why a picker
/// that only mutates the locale environment never actually changed any text.
///
/// We swap `Bundle.main` to an instance of this class on app launch so that
/// every `Text("key")`, `String(localized: "...")`, and `LocalizedStringKey`
/// resolves against the override's `.lproj` immediately, no restart required.
private final class OverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let override = LocalizationManager.shared.override
        if !override.isEmpty,
           let path = Bundle.main.path(forResource: override, ofType: "lproj"),
           let overrideBundle = Bundle(path: path) {
            return overrideBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// Centralized language override for the in-app language picker.
///
/// The picker is fully in-process: switching language re-renders all SwiftUI
/// views with the chosen `.lproj` instantly (no app restart). We do this by
/// reclassing `Bundle.main` to `OverrideBundle` at first init so every
/// localized lookup checks the override before falling back to system locale.
///
/// `AppleLanguages` is also written so any UIKit-bridged code (alerts, system
/// pickers, share sheet titles) matches on the *next* launch as well.
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
    /// Drives date/number/currency formatting (Bundle resource lookup is
    /// handled separately by the `OverrideBundle` swap above).
    var currentLocale: Locale {
        if override.isEmpty {
            return .current
        }
        return Locale(identifier: override)
    }

    private init() {
        self.override = UserDefaults.standard.string(forKey: storageKey) ?? ""
        Self.installBundleOverride()
        applyAppleLanguages(override)
    }

    /// Sets a new override. Pass "" to revert to system default.
    func setOverride(_ code: String) {
        let normalized = Self.supportedLanguages.contains(code) ? code : ""
        override = normalized
        applyAppleLanguages(normalized)
    }

    private func persist() {
        UserDefaults.standard.set(override, forKey: storageKey)
    }

    /// One-time class swap on `Bundle.main` so localized lookup checks override
    /// first. Safe to call multiple times: the `is OverrideBundle` guard makes
    /// it a no-op on second call.
    private static func installBundleOverride() {
        guard !(Bundle.main is OverrideBundle) else { return }
        object_setClass(Bundle.main, OverrideBundle.self)
    }

    /// Writes (or clears) the AppleLanguages preference. iOS reads this on
    /// next launch for UIKit-side localization. SwiftUI strings update in
    /// real time within the running process via the `OverrideBundle` swap.
    private func applyAppleLanguages(_ code: String) {
        let defaults = UserDefaults.standard
        if code.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([code], forKey: "AppleLanguages")
        }
    }

    /// Hardcoded native-script display names for each supported language.
    ///
    /// `Locale.localizedString(forLanguageCode:)` returns the *language* component only
    /// and ignores the script — both `zh-Hans` and `zh-Hant` would render as "Chinese",
    /// leaving the picker with two identical entries. This dictionary keeps the picker
    /// readable in every locale.
    static let displayNames: [String: String] = [
        "en":      "English",
        "ja":      "日本語",
        "ko":      "한국어",
        "zh-Hans": "简体中文",
        "zh-Hant": "繁體中文",
        "es":      "Español",
        "fr":      "Français",
        "de":      "Deutsch",
    ]

    static func displayName(for code: String) -> String {
        if code.isEmpty {
            return String(localized: "System default")
        }
        if let native = displayNames[code] {
            return native
        }
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)
            ?? Locale.current.localizedString(forIdentifier: code)
            ?? code
    }
}
