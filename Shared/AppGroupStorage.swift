import Foundation

/// Non-secret settings shared between the main app and the keyboard extension via the App
/// Group's `UserDefaults`.
///
/// API keys are **not** kept here, they live in the shared Keychain (`CredentialStore`).
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
        static let aiMode = "ai_mode"
        static let installID = "install_id"
        static let hasSeenOnboarding = "has_seen_onboarding"
        static let keyboardLastActive = "keyboard_last_active"
    }

    /// When the keyboard extension was last active with Full Access (it can only reach this shared
    /// store when Full Access is on, so a recorded date means "installed and working"). Read by the
    /// app to show the "Keyboard is set up" status. `nil` until the keyboard has run at least once.
    var keyboardLastActive: Date? {
        get {
            let t = defaults.double(forKey: Keys.keyboardLastActive)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        nonmutating set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Keys.keyboardLastActive) }
    }

    /// Whether the keyboard has ever been active with Full Access (proxy for "set up").
    var keyboardIsSetUp: Bool { keyboardLastActive != nil }

    /// Called by the keyboard extension (with Full Access) to record that it is installed and running.
    func recordKeyboardActive() { keyboardLastActive = Date() }

    /// Whether the consumer welcome flow has been shown. Existing users (who already configured a
    /// provider key) are treated as having seen it, so an update doesn't re-show onboarding.
    var hasSeenOnboarding: Bool {
        get {
            if defaults.object(forKey: Keys.hasSeenOnboarding) != nil {
                return defaults.bool(forKey: Keys.hasSeenOnboarding)
            }
            return AIProviderType.allCases.contains { CredentialStore.shared.hasAPIKey(for: $0) }
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.hasSeenOnboarding) }
    }

    /// How the app gets AI: `keyglot` (AI included via backend) or `custom` (user's own key).
    /// Until the user chooses explicitly, the default is safe for everyone: **existing users**
    /// (who already have a provider key) stay on Custom (no regression), **new installs** get
    /// KeyGlot. Correct in the app *and* the extensions without a separate migration step.
    var aiMode: AIMode {
        get {
            if let raw = defaults.string(forKey: Keys.aiMode), let mode = AIMode(rawValue: raw) {
                return mode
            }
            let hasAnyKey = AIProviderType.allCases.contains { CredentialStore.shared.hasAPIKey(for: $0) }
            return hasAnyKey ? .custom : .keyglot
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Keys.aiMode) }
    }

    /// Stable random id for this install, used as the KeyGlot subject before StoreKit identity
    /// exists. Generated once and shared across the app + extensions via the App Group.
    var installID: String {
        if let existing = defaults.string(forKey: Keys.installID), !existing.isEmpty { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: Keys.installID)
        return id
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

    /// Number of translations so far, drives the "support Keyglot" reminder. Counted across all
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
