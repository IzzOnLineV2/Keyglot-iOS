import SwiftUI
import UIKit

/// The share extension's UI for translated **text**: a spinner, then the translation (prominent)
/// plus the original, or an error.
struct TextShareView: View {
    @ObservedObject var model: TextShareModel
    let onClose: () -> Void

    @StateObject private var speech = SpeechReader()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                KGColor.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Keyglot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done"), action: onClose)
                        .foregroundStyle(KGColor.accent)
                }
            }
            .onDisappear { speech.stop() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .working(let label):
            VStack(spacing: 16) {
                SpinnerRing()
                Text(label.isEmpty ? String(localized: "Translating…") : label)
                    .font(KGFont.body).foregroundStyle(KGColor.ink2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(KGColor.attention)
                Text(message)
                    .font(KGFont.body).multilineTextAlignment(.center).foregroundStyle(KGColor.ink2)
            }
            .padding().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .done(let original, let translation):
            ScrollView {
                VStack(spacing: 14) {
                    TranslationResultCard(translation: translation, original: original)
                    resultActions(translation)
                    hintBanner
                }
                .padding()
            }
        }
    }

    private func resultActions(_ translation: String) -> some View {
        HStack(spacing: 9) {
            Button {
                speech.toggle(translation, voiceCode: VoiceLanguage.targetVoiceCode(for: "auto"))
            } label: {
                Label(speech.isSpeaking ? "Stop" : "Read aloud",
                      systemImage: speech.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(.kgSecondary)
            Button {
                UIPasteboard.general.string = translation
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.kgSecondary)
        }
    }

    /// Nudge to reply in the same chat with the Keyglot keyboard.
    private var hintBanner: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "keyboard").font(.system(size: 14)).foregroundStyle(KGColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ready to answer?").font(KGFont.caption.weight(.semibold)).foregroundStyle(KGColor.ink)
                Text("Close this and use the Keyglot keyboard in the chat, right where you're typing.")
                    .font(KGFont.caption).foregroundStyle(KGColor.ink2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KGColor.accentTint, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
    }
}
