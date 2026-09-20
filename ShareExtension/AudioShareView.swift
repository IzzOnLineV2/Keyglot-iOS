import SwiftUI
import UIKit

/// The share extension's UI for a received voice note: a source-language pill, an equalizer while
/// transcribing/translating, then the translation (prominent) + original transcript, or an error.
/// Changing the language re-runs on the same audio, handy when a dialect is misread.
struct AudioShareView: View {
    @ObservedObject var model: AudioShareModel
    let onClose: () -> Void

    @StateObject private var speech = SpeechReader()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                KGColor.canvas.ignoresSafeArea()
                VStack(spacing: 14) {
                    sourcePill
                        .padding(.horizontal)
                        .padding(.top, 12)
                    content
                }
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

    private var currentLanguageName: String {
        VoiceLanguage.option(for: model.selectedID).name
    }

    private var sourcePill: some View {
        Menu {
            ForEach(VoiceLanguage.options) { lang in
                Button {
                    model.setLanguage(lang.id)
                } label: {
                    if lang.id == model.selectedID {
                        Label(lang.name, systemImage: "checkmark")
                    } else {
                        Text(lang.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe").foregroundStyle(KGColor.accent)
                Text(String(localized: "Audio language")).foregroundStyle(KGColor.ink)
                Spacer()
                Text(currentLanguageName).foregroundStyle(KGColor.ink2)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(KGColor.ink3)
            }
            .font(KGFont.row)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(KGColor.surface, in: RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous)
                    .strokeBorder(KGColor.border, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .working(let label):
            VStack(spacing: 16) {
                EqualizerBars(color: KGColor.accent)
                Text(label.isEmpty ? String(localized: "Translating…") : label)
                    .font(KGFont.body).foregroundStyle(KGColor.ink2)
                Text("Dialects can take a moment longer.")
                    .font(KGFont.caption).foregroundStyle(KGColor.ink3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(KGColor.attention)
                Text(message)
                    .font(KGFont.body).multilineTextAlignment(.center).foregroundStyle(KGColor.ink2)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .done(let transcript, let translation):
            ScrollView {
                VStack(spacing: 14) {
                    TranslationResultCard(
                        translation: translation,
                        original: transcript,
                        originalLabel: "Word for word"
                    )
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

    /// Explains what the source-language picker does (re-runs on the same audio, no re-sharing).
    private var hintBanner: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "arrow.clockwise").font(.system(size: 14)).foregroundStyle(KGColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("If a dialect came out wrong").font(KGFont.caption.weight(.semibold)).foregroundStyle(KGColor.ink)
                Text("Pick the language above and Keyglot listens again, same recording, no re-sharing.")
                    .font(KGFont.caption).foregroundStyle(KGColor.ink2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KGColor.accentTint, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
    }
}
