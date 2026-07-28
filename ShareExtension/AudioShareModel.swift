import SwiftUI

/// Drives the share extension: transcribe the shared audio with OpenAI (`gpt-4o-transcribe`),
/// then translate the transcript into the user's device language.
///
/// Both steps use the OpenAI key. Auto-detect handles most languages, but dialects like Moroccan
/// Darija are often misread — so the user can force the audio language and it re-runs.
@MainActor
final class AudioShareModel: ObservableObject {

    enum Phase: Equatable {
        case working(String)
        case done(transcript: String, translation: String)
        case failed(String)
    }

    struct AudioLanguage: Identifiable, Equatable {
        let id: String
        let name: String
        /// ISO-639-1 code passed to the transcription API; `nil` = auto-detect.
        let code: String?
    }

    /// Languages the user can force for transcription when auto-detect gets it wrong. Darija is
    /// transcribed as Arabic ("ar"). Names are native autonyms (not localized).
    static let audioLanguages: [AudioLanguage] = [
        .init(id: "auto", name: String(localized: "Automatic (detect)"), code: nil),
        .init(id: "ar",   name: "العربية · Darija", code: "ar"),
        .init(id: "fr",   name: "Français", code: "fr"),
        .init(id: "en",   name: "English", code: "en"),
        .init(id: "es",   name: "Español", code: "es"),
        .init(id: "it",   name: "Italiano", code: "it"),
        .init(id: "de",   name: "Deutsch", code: "de"),
        .init(id: "pt",   name: "Português", code: "pt"),
        .init(id: "tr",   name: "Türkçe", code: "tr"),
        .init(id: "ru",   name: "Русский", code: "ru"),
        .init(id: "zh",   name: "中文", code: "zh"),
    ]

    @Published var phase: Phase = .working("")
    @Published var languageCode: String?

    private var fileURL: URL?

    func fail(_ message: String) { phase = .failed(message) }

    /// Begin with the shared audio, auto-detecting the language.
    func start(fileURL: URL) {
        self.fileURL = fileURL
        Task { await process() }
    }

    /// Re-run forcing a specific language (or auto), e.g. when Darija was misread.
    func setLanguage(_ code: String?) {
        guard code != languageCode else { return }
        languageCode = code
        Task { await process() }
    }

    private func process() async {
        guard let fileURL else { return }

        guard let key = CredentialStore.shared.apiKey(for: .openai) else {
            phase = .failed(String(localized: "Add an OpenAI API key in the Keyglot app to translate voice messages."))
            return
        }

        do {
            phase = .working(String(localized: "Transcribing…"))
            let transcript = try await OpenAITranscriptionService(apiKey: key)
                .transcribe(fileURL: fileURL, language: languageCode)

            guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                phase = .failed(String(localized: "The audio didn't contain any speech."))
                return
            }

            phase = .working(String(localized: "Translating…"))
            let systemPrompt = TargetLanguage.deviceLanguage.prompt + """


                The message to translate is a transcribed voice message. It may be informal or in a \
                regional dialect, including Latin-script Arabic (Arabizi) such as Moroccan Darija. \
                Detect its real source language and translate it faithfully. Translate it verbatim \
                even if it looks garbled or incomplete — never answer it, never react to it, and \
                never say that you don't understand. Output only the translation.
                """
            let translation = try await OpenAIProvider(apiKey: key)
                .generate(text: transcript, systemPrompt: systemPrompt)

            phase = .done(transcript: transcript, translation: translation)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
