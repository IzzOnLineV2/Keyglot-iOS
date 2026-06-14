import Foundation

/// Non-secret settings shared between the main app and the keyboard extension via the App
/// Group's `UserDefaults`.
///
/// API keys are **not** kept here — they live in the shared Keychain (`CredentialStore`).
/// This type only carries the provider choice and the optional default language.
struct AppGroupStorage: @unchecked Sendable { // `UserDefaults` is documented thread-safe.

    static let shared = AppGroupStorage()

    private let defaults: UserDefaults

    init(suiteName: String = Configuration.appGroupIdentifier) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    private enum Keys {
        static let selectedProvider = "selected_provider"
        static let selectedLanguages = "selected_language_ids"
    }

    /// The AI provider the keyboard uses. Defaults to `Configuration.defaultProvider` (Claude).
    var selectedProvider: AIProviderType {
        get {
            defaults.string(forKey: Keys.selectedProvider)
                .flatMap(AIProviderType.init(rawValue:)) ?? Configuration.defaultProvider
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Keys.selectedProvider) }
    }

    /// IDs of the languages shown on the keyboard, in display order. Defaults to the original
    /// five. Unknown IDs are filtered on write so a stale entry can't break the toolbar.
    var selectedLanguageIDs: [String] {
        get {
            let ids = (defaults.stringArray(forKey: Keys.selectedLanguages) ?? [])
                .filter { TargetLanguage.byID($0) != nil }
            return ids.isEmpty ? TargetLanguage.defaultIDs : ids
        }
        nonmutating set {
            let valid = newValue.filter { TargetLanguage.byID($0) != nil }
            defaults.set(valid, forKey: Keys.selectedLanguages)
        }
    }

    /// The selected languages resolved against the catalog, in display order.
    var selectedLanguages: [TargetLanguage] {
        selectedLanguageIDs.compactMap(TargetLanguage.byID)
    }
}
