import SwiftUI

/// The share extension's UI: a language selector at the top (auto by default), a spinner while
/// transcribing/translating, then the translation (prominent) plus the original transcript, or
/// an error. Changing the language re-runs on the same audio — handy when a dialect is misread.
struct AudioShareView: View {
    @ObservedObject var model: AudioShareModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                languagePicker
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
                content
            }
            .navigationTitle("Keyglot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done"), action: onClose)
                }
            }
        }
    }

    private var currentLanguageName: String {
        AudioShareModel.audioLanguages.first { $0.code == model.languageCode }?.name
            ?? AudioShareModel.audioLanguages[0].name
    }

    private var languagePicker: some View {
        Menu {
            ForEach(AudioShareModel.audioLanguages) { lang in
                Button {
                    model.setLanguage(lang.code)
                } label: {
                    if lang.code == model.languageCode {
                        Label(lang.name, systemImage: "checkmark")
                    } else {
                        Text(lang.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(String(localized: "Audio language"))
                Spacer()
                Text(currentLanguageName)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .working(let label):
            VStack(spacing: 14) {
                ProgressView()
                Text(label.isEmpty ? String(localized: "Working…") : label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .done(let transcript, let translation):
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(title: String(localized: "Translation"), text: translation, prominent: true)
                    section(title: String(localized: "Original transcript"), text: transcript, prominent: false)
                }
                .padding()
            }
        }
    }

    private func section(title: String, text: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(text)
                .font(prominent ? .body : .callout)
                .foregroundStyle(prominent ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
