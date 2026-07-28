import SwiftUI

/// Drives the share extension: transcribe the shared audio with OpenAI Whisper, then translate
/// the transcript into the user's device language.
///
/// Both steps use the OpenAI key — audio needs an audio-capable provider, and Whisper
/// auto-detects the spoken language, so this works even for languages the user doesn't know.
@MainActor
final class AudioShareModel: ObservableObject {

    enum Phase: Equatable {
        case working(String)
        case done(transcript: String, translation: String)
        case failed(String)
    }

    @Published var phase: Phase = .working("")

    func fail(_ message: String) { phase = .failed(message) }

    func run(fileURL: URL) async {
        defer { try? FileManager.default.removeItem(at: fileURL) }

        guard let key = CredentialStore.shared.apiKey(for: .openai) else {
            phase = .failed(String(localized: "Add an OpenAI API key in the Keyglot app to translate voice messages."))
            return
        }

        do {
            phase = .working(String(localized: "Transcribing…"))
            let transcript = try await OpenAITranscriptionService(apiKey: key).transcribe(fileURL: fileURL)

            guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                phase = .failed(String(localized: "The audio didn't contain any speech."))
                return
            }

            phase = .working(String(localized: "Translating…"))
            let translation = try await OpenAIProvider(apiKey: key)
                .generate(text: transcript, systemPrompt: TargetLanguage.deviceLanguage.prompt)

            phase = .done(transcript: transcript, translation: translation)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
