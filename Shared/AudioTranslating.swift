import Foundation

/// Result of transcribing + translating a voice message.
struct AudioTranslation: Sendable, Equatable {
    let transcript: String
    let translation: String
}

/// Abstraction over "listen to this clip and give me transcript + translation", so the audio
/// call sites (share extension, in-app Listen) don't know whether the work happens via the user's
/// own Gemini key (Custom mode) or through the KeyGlot backend (KeyGlot mode).
protocol AudioTranslating: Sendable {
    func translate(
        fileURL: URL,
        mimeType: String,
        targetLanguage: String,
        sourceHint: String?
    ) async throws -> AudioTranslation
}
