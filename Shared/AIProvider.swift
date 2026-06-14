import Foundation

/// The single abstraction the keyboard depends on. Swapping providers (or adding new ones)
/// never touches the keyboard logic — only this file's `AIProviderType`/`AIProviderFactory`.
protocol AIProvider: Sendable {
    func translate(text: String, targetLanguage: TargetLanguage) async throws -> String
}

/// The available AI providers. Claude Sonnet is the default; OpenAI is wired up and ready,
/// so a future settings toggle is purely a UI change.
enum AIProviderType: String, CaseIterable, Identifiable, Codable, Sendable {
    case claude
    case openai
    case gemini
    case openrouter

    var id: String { rawValue }

    /// Label shown in the provider picker.
    var displayName: String {
        switch self {
        case .claude:     return "Claude Sonnet"
        case .openai:     return "OpenAI GPT"
        case .gemini:     return "Google Gemini"
        case .openrouter: return "OpenRouter"
        }
    }

    /// The model this provider currently uses, for display in the app.
    var modelName: String {
        switch self {
        case .claude:     return Configuration.claudeModel
        case .openai:     return Configuration.openAIDefaultModel
        case .gemini:     return Configuration.geminiModel
        case .openrouter: return Configuration.openRouterModel
        }
    }

    /// How the provider's secret is labelled in the API-key screen.
    var apiKeyName: String {
        switch self {
        case .claude:     return "Anthropic API Key"
        case .openai:     return "OpenAI API Key"
        case .gemini:     return "Google AI API Key"
        case .openrouter: return "OpenRouter API Key"
        }
    }

    /// Hint shown under the key field.
    var apiKeyPlaceholder: String {
        switch self {
        case .claude:     return "sk-ant-…"
        case .openai:     return "sk-…"
        case .gemini:     return "AIza…"
        case .openrouter: return "sk-or-…"
        }
    }

    /// Where the user can create an API key for this provider.
    var apiKeyURL: URL {
        switch self {
        case .claude:     return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai:     return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini:     return URL(string: "https://aistudio.google.com/app/apikey")!
        case .openrouter: return URL(string: "https://openrouter.ai/keys")!
        }
    }
}

/// A configuration error: the selected provider has no API key yet.
enum AIProviderError: Error, LocalizedError {
    case missingAPIKey(AIProviderType)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Add your \(provider.displayName) API key in the app first."
        }
    }
}

/// Errors shared by the concrete providers' network calls.
enum ProviderError: Error, LocalizedError {
    case invalidResponse
    case http(status: Int, message: String)
    case emptyOutput
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:          return "Unexpected response from the AI provider."
        case .http(let status, let m):  return "Provider error \(status): \(m)"
        case .emptyOutput:              return "The AI provider returned no text."
        case .transport(let error):     return error.localizedDescription
        }
    }

    /// Whether this means "the model is unusable" (worth trying a fallback model) rather than
    /// a transient/network problem.
    var isModelRejection: Bool {
        if case .http(let status, _) = self {
            return status == 400 || status == 404 || status == 403
        }
        return false
    }
}

/// Builds the concrete provider for the user's current selection. The API key comes from the
/// shared Keychain (`CredentialStore`), never from `UserDefaults`.
enum AIProviderFactory {
    static func make(
        storage: AppGroupStorage = .shared,
        credentials: CredentialStore = .shared
    ) throws -> any AIProvider {
        let type = storage.selectedProvider
        guard let apiKey = credentials.apiKey(for: type) else {
            throw AIProviderError.missingAPIKey(type)
        }
        return make(type, apiKey: apiKey)
    }

    /// Build a provider for an explicit type + key — used by the in-app connection test.
    static func make(_ type: AIProviderType, apiKey: String) -> any AIProvider {
        switch type {
        case .claude:     return ClaudeProvider(apiKey: apiKey)
        case .openai:     return OpenAIProvider(apiKey: apiKey)
        case .gemini:     return GeminiProvider(apiKey: apiKey)
        case .openrouter: return OpenRouterProvider(apiKey: apiKey)
        }
    }
}
