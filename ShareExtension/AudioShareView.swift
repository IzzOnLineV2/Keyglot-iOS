import SwiftUI

/// The share extension's UI for a received voice note: a source-language pill, an equalizer while
/// transcribing/translating, then the translation (prominent) + original transcript, or an error.
/// Changing the language re-runs on the same audio — handy when a dialect is misread.
struct AudioShareView: View {
    @ObservedObject var model: AudioShareModel
    let onClose: () -> Void

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
                TranslationResultCard(
                    translation: translation,
                    original: transcript,
                    originalLabel: "Original transcript"
                )
                .padding()
            }
        }
    }
}
