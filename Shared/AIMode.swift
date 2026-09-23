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
        let base: any AIProvider
        let modelID: String
        switch storage.aiMode {
        case .keyglot:
            base = KeyGlotProvider(session: KeyGlotSession(storage: storage, credentials: credentials))
            modelID = "keyglot"
        case .custom:
            base = try AIProviderFactory.make(storage: storage, credentials: credentials)
            let p = storage.selectedProvider
            modelID = "custom:\(p.rawValue):\(p.modelName)"
        }
        // Cache identical requests (same text + system prompt + model) to avoid re-spending tokens.
        return CachedProvider(wrapped: base, modelID: modelID)
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
