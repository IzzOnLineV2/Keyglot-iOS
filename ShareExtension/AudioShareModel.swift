import SwiftUI

/// Drives the share extension: send the shared audio to Google Gemini, which "listens" and
/// returns a transcript + a translation into the user's device language, in one call.
///
/// Gemini handles regional dialects (e.g. Moroccan Darija) far better than literal speech-to-text.
/// Requires a **Gemini** API key. The user can force the likely source language if auto-detect is
/// off; changing it re-runs on the same audio.
@MainActor
final class AudioShareModel: ObservableObject {

    enum Phase: Equatable {
        case working(String)
        case done(transcript: String, translation: String)
        case failed(String)
    }

    struct AudioLanguage: Identifiable, Equatable {
        let id: String
        /// Shown in the picker (native autonym).
        let name: String
        /// English hint passed to Gemini as the likely source language; `nil` = auto-detect.
        let hint: String?
    }

    /// Source-language options for the picker. Auto-detect works for most; the Darija hint helps
    /// when a dialect is misheard.
    static let audioLanguages: [AudioLanguage] = [
        .init(id: "auto", name: String(localized: "Automatic (detect)"), hint: nil),
        .init(id: "ar",   name: "العربية · Darija", hint: "Moroccan Darija (Arabic)"),
        .init(id: "fr",   name: "Français", hint: "French"),
        .init(id: "en",   name: "English", hint: "English"),
        .init(id: "es",   name: "Español", hint: "Spanish"),
        .init(id: "it",   name: "Italiano", hint: "Italian"),
        .init(id: "de",   name: "Deutsch", hint: "German"),
        .init(id: "pt",   name: "Português", hint: "Portuguese"),
        .init(id: "tr",   name: "Türkçe", hint: "Turkish"),
        .init(id: "ru",   name: "Русский", hint: "Russian"),
        .init(id: "zh",   name: "中文", hint: "Chinese"),
    ]

    @Published var phase: Phase = .working("")
    /// Restored from the App Group so the last-picked language (e.g. Darija) sticks.
    @Published var selectedID = AppGroupStorage.shared.audioLanguageID

    private var fileURL: URL?

    func fail(_ message: String) { phase = .failed(message) }

    /// Begin with the shared audio, auto-detecting the language.
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

        let hint = Self.audioLanguages.first { $0.id == selectedID }?.hint

        do {
            phase = .working(String(localized: "Translating…"))
            let result = try await GeminiAudioTranslator(apiKey: key).translate(
                fileURL: fileURL,
                mimeType: Self.mimeType(for: fileURL),
                targetLanguage: Self.deviceLanguageEnglishName,
                sourceHint: hint
            )
            phase = .done(transcript: result.transcript, translation: result.translation)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Gemini audio MIME for the file. The wrong MIME makes Gemini mis-decode the audio, so map
    /// carefully: WhatsApp voice notes are m4a (→ audio/mp4) or opus (→ audio/ogg).
    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "opus", "ogg", "oga": return "audio/ogg"
        case "mp3", "mpga", "mpeg": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "flac": return "audio/flac"
        default: return "audio/mp4"   // m4a / mp4 — WhatsApp's default
        }
    }

    /// English name of the device language (e.g. "Italian"), used in the Gemini prompt.
    private static var deviceLanguageEnglishName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
    }
}
