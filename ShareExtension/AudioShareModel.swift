import SwiftUI

/// Drives the share extension: send the shared audio to Google Gemini, which "listens" and
/// returns a transcript + a translation into the user's device language, in one call.
///
/// Gemini handles regional dialects (e.g. Moroccan Darija) far better than literal speech-to-text.
/// Requires a **Gemini** API key. Source-language options + helpers live in `VoiceLanguage`; the
/// last choice is remembered so the user doesn't re-pick (e.g. Darija) every time.
@MainActor
final class AudioShareModel: ObservableObject {

    enum Phase: Equatable {
        case working(String)
        case done(transcript: String, translation: String)
        case failed(String)
    }

    @Published var phase: Phase = .working("")
    @Published var selectedID = AppGroupStorage.shared.audioLanguageID

    private var fileURL: URL?

    func fail(_ message: String) { phase = .failed(message) }

    /// Begin with the shared audio, using the remembered language.
    func start(fileURL: URL) {
        self.fileURL = fileURL
        Task { await process() }
    }

    /// Re-run forcing a specific source language (or auto), e.g. when Darija was misheard.
    func setLanguage(_ id: String) {
        guard id != selectedID else { return }
        selectedID = id
        AppGroupStorage.shared.audioLanguageID = id   // remember for next time
        Task { await process() }
    }

    private func process() async {
        guard let fileURL else { return }

        guard let key = CredentialStore.shared.apiKey(for: .gemini) else {
            phase = .failed(String(localized: "Add a Google Gemini API key in the Keyglot app to translate voice messages."))
            return
        }

        do {
            phase = .working(String(localized: "Translating…"))
            let result = try await GeminiAudioTranslator(apiKey: key).translate(
                fileURL: fileURL,
                mimeType: VoiceLanguage.mimeType(for: fileURL),
                targetLanguage: VoiceLanguage.deviceLanguageEnglishName,
                sourceHint: VoiceLanguage.hint(for: selectedID)
            )
            phase = .done(transcript: result.transcript, translation: result.translation)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
