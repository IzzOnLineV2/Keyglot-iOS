import Foundation

/// Central, compile-time configuration shared by the app and the keyboard extension.
///
/// Nothing secret lives here — provider API keys are supplied by the user at runtime
/// and stored in the shared App Group (see `AppGroupStorage`).
enum Configuration {

    /// App Group used to share settings between the main app and the keyboard extension.
    /// Must match the `com.apple.security.application-groups` entitlement of both targets.
    static let appGroupIdentifier = "group.it.izzonline.keyglot"

    /// Provider used when the user hasn't chosen one yet. Claude Sonnet is the default for
    /// its strong multilingual, conversational translation quality.
    static let defaultProvider: AIProviderType = .claude

    /// Network timeout for a single translation request.
    static let requestTimeout: TimeInterval = 30

    /// Maximum number of languages the user can pin to the keyboard toolbar.
    static let maxKeyboardLanguages = 7

    // MARK: - Anthropic (Claude)

    /// Anthropic Messages API endpoint.
    static let anthropicMessagesURL = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Required `anthropic-version` header value.
    static let anthropicVersion = "2023-06-01"

    /// "Claude Sonnet" → the current Sonnet model id.
    static let claudeModel = "claude-sonnet-4-6"

    /// Upper bound on the response length. A cap, not a target — short chat messages finish
    /// well under it, and it costs nothing extra, so it's set generously to avoid truncation.
    static let claudeMaxTokens = 4096

    // MARK: - OpenAI (future provider)

    /// OpenAI Responses API endpoint.
    static let openAIResponsesURL = URL(string: "https://api.openai.com/v1/responses")!

    /// Default OpenAI model.
    static let openAIDefaultModel = "gpt-5-mini"

    /// Fallback OpenAI model, used only when the default model is rejected by the account.
    static let openAIFallbackModel = "gpt-5-nano"

    /// Reasoning effort for the OpenAI Responses API. `nil` omits the field.
    static let openAIReasoningEffort: String? = "low"

    // MARK: - Google Gemini

    static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    /// Configurable — e.g. "gemini-2.5-flash".
    static let geminiModel = "gemini-2.0-flash"

    static func geminiURL(model: String = geminiModel) -> URL {
        URL(string: "\(geminiBaseURL)/\(model):generateContent")!
    }

    // MARK: - OpenRouter (OpenAI-compatible gateway)

    static let openRouterURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// Configurable — any OpenRouter model id in `vendor/model` form.
    static let openRouterModel = "openai/gpt-4o-mini"

    /// Optional attribution headers OpenRouter uses for ranking.
    static let openRouterReferer = "https://smartapibox.com"
    static let openRouterTitle = "Keyglot"
}
