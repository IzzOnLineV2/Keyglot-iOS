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
        static let audioLanguageID = "audio_language_id"
        static let pendingListen = "pending_listen"
        static let useCount = "use_count"
        static let isSupporter = "is_supporter"
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

    /// Source language last chosen in the share extension's audio translator ("auto" by default),
    /// so the user doesn't have to re-pick (e.g. Darija) on every voice message.
    var audioLanguageID: String {
        get { defaults.string(forKey: Keys.audioLanguageID) ?? "auto" }
        nonmutating set { defaults.set(newValue, forKey: Keys.audioLanguageID) }
    }

    /// Set by the widget's App Intent to ask the app to jump into "Listen & translate" on launch.
    var pendingListen: Bool {
        get { defaults.bool(forKey: Keys.pendingListen) }
        nonmutating set { defaults.set(newValue, forKey: Keys.pendingListen) }
    }

    /// Number of translations so far — drives the "support Keyglot" reminder. Counted across all
    /// surfaces (keyboard, share, listen); frozen once the user has purchased.
    var useCount: Int {
        get { defaults.integer(forKey: Keys.useCount) }
        nonmutating set { defaults.set(newValue, forKey: Keys.useCount) }
    }

    /// Whether the user bought the one-time "support" purchase (cached from StoreKit by the app so
    /// the extensions can stop counting). Source of truth is StoreKit's entitlements.
    var isSupporter: Bool {
        get { defaults.bool(forKey: Keys.isSupporter) }
        nonmutating set { defaults.set(newValue, forKey: Keys.isSupporter) }
    }

    /// Count one successful translation toward the reminder (no-op once purchased).
    func recordUse() {
        guard !isSupporter else { return }
        useCount += 1
    }
}
