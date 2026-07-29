import SwiftUI

/// Translates shared **text** (a selection, a note, a link) into the user's device language,
/// using the provider the user selected in the app (Claude by default) — no Gemini requirement.
@MainActor
final class TextShareModel: ObservableObject {

    enum Phase: Equatable {
        case working(String)
        case done(original: String, translation: String)
        case failed(String)
    }

    @Published var phase: Phase = .working("")

    func fail(_ message: String) { phase = .failed(message) }

    func translate(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .failed(String(localized: "Nothing to translate here."))
            return
        }

        phase = .working(String(localized: "Translating…"))
        do {
            let provider = try AIProviderFactory.make()   // selected provider + its Keychain key
            let translation = try await provider.generate(
                text: trimmed,
                systemPrompt: TargetLanguage.deviceLanguage.prompt
            )
            phase = .done(original: trimmed, translation: translation)
            AppGroupStorage.shared.recordUse()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
