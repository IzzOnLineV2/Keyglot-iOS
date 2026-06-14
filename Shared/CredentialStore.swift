import Foundation

/// The single place that reads/writes provider API keys. Backed by the shared Keychain —
/// API keys are **never** stored in `UserDefaults`.
struct CredentialStore: Sendable {

    static let shared = CredentialStore()

    private let keychain: KeychainStore

    init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
    }

    func apiKey(for provider: AIProviderType) -> String? {
        keychain.string(account: account(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    /// Returns `true` on success. A `false` here means the Keychain write was rejected
    /// (most commonly `errSecMissingEntitlement` on an unsigned build) — the caller should
    /// surface that rather than assume the key was stored.
    @discardableResult
    func setAPIKey(_ key: String?, for provider: AIProviderType) -> Bool {
        keychain.set(key?.trimmingCharacters(in: .whitespacesAndNewlines),
                     account: account(for: provider))
    }

    func hasAPIKey(for provider: AIProviderType) -> Bool {
        apiKey(for: provider) != nil
    }

    private func account(for provider: AIProviderType) -> String {
        "api_key_\(provider.rawValue)"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
