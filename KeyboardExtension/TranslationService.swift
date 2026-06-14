import Foundation

/// High-level entry point used by the keyboard for both translation and rewriting.
///
/// Resolves the user's selected provider (via `AIProviderFactory`) and delegates to it
/// through the `AIProvider` protocol — the keyboard never knows which provider ran.
struct TranslationService: Sendable {

    enum ServiceError: Error, LocalizedError {
        case emptyInput

        var errorDescription: String? {
            switch self {
            case .emptyInput: return "Nothing to process."
            }
        }
    }

    private let storage: AppGroupStorage

    init(storage: AppGroupStorage = .shared) {
        self.storage = storage
    }

    /// Translate the message into `language` (source language auto-detected).
    func translate(_ text: String, to language: TargetLanguage) async throws -> String {
        try await run(text, systemPrompt: language.prompt)
    }

    /// Rewrite the message in the same language, applying `action`'s tone/quality change.
    func rewrite(_ text: String, as action: RewriteAction) async throws -> String {
        try await run(text, systemPrompt: action.prompt)
    }

    private func run(_ text: String, systemPrompt: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyInput }

        let provider = try AIProviderFactory.make(storage: storage)
        return try await provider.generate(text: text, systemPrompt: systemPrompt)
    }
}
