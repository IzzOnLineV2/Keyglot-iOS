import Foundation

/// How the app gets AI. `keyglot` = AI included via the KeyGlot backend (no user key); `custom`
/// = the user's own provider + API key (today's behaviour, requests go straight to the provider).
enum AIMode: String, CaseIterable, Identifiable, Sendable {
    case keyglot
    case custom

    var id: String { rawValue }
    var displayName: String { self == .keyglot ? "KeyGlot" : "Custom" }
}

/// Picks the right implementation for the current `AIMode`. In `.custom` this is exactly the old
/// path (`AIProviderFactory` / `GeminiAudioTranslator` with the user's key); in `.keyglot` it
/// routes through the KeyGlot backend. Call sites stay mode-agnostic.
enum AIResolver {
    static func textProvider(
        storage: AppGroupStorage = .shared,
        credentials: CredentialStore = .shared
    ) throws -> any AIProvider {
        switch storage.aiMode {
        case .keyglot:
            return KeyGlotProvider(session: KeyGlotSession(storage: storage, credentials: credentials))
        case .custom:
            return try AIProviderFactory.make(storage: storage, credentials: credentials)
        }
    }

    static func audioTranslator(
        storage: AppGroupStorage = .shared,
        credentials: CredentialStore = .shared
    ) throws -> any AudioTranslating {
        switch storage.aiMode {
        case .keyglot:
            return KeyGlotAudioTranslator(session: KeyGlotSession(storage: storage, credentials: credentials))
        case .custom:
            guard let key = credentials.apiKey(for: .gemini) else {
                throw AIProviderError.missingAPIKey(.gemini)
            }
            return GeminiAudioTranslator(apiKey: key)
        }
    }
}
