import Foundation

/// High-level translation entry point used by the keyboard.
///
/// Resolves the user's selected provider (via `AIProviderFactory`) and delegates to it
/// through the `AIProvider` protocol — the keyboard never knows which provider ran.
struct TranslationService: Sendable {

    enum ServiceError: Error, LocalizedError {
        case emptyInput

        var errorDescription: String? {
            switch self {
            case .emptyInput: return "Nothing to translate."
            }
        }
    }

    private let storage: AppGroupStorage

    init(storage: AppGroupStorage = .shared) {
        self.storage = storage
    }

    func translate(_ text: String, to language: TargetLanguage) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyInput }

        let provider = try AIProviderFactory.make(storage: storage)
        return try await provider.translate(text: text, targetLanguage: language)
    }
}
