import SwiftUI

struct AboutView: View {
    private let provider = AppGroupStorage.shared.selectedProvider
    private let languages = AppGroupStorage.shared.selectedLanguages

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyglot")
                        .font(.headline)
                    Text("AI Message Translator")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Keyglot translates or rewrites the message you've already typed — in place, without copy/paste. Tap a language for a natural translation (source language auto-detected), or tap a tone to improve or restyle your text in the same language.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("How it works") {
                bullet("Type your message in any app with your normal keyboard.")
                bullet("Tap 🌐 to switch to the Keyglot keyboard.")
                bullet("Tap a language to translate, or a tone (✨ 💼 😊 ❤️) to rewrite — the text is replaced in place.")
                bullet("Press Send.")
                bullet("Choose which languages appear in Settings → Keyboard → Languages.")
            }

            Section("Keyboard languages") {
                ForEach(languages) { language in
                    LabeledContent(language.name) { Text(language.flag) }
                }
            }

            Section {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Provider", value: provider.displayName)
                LabeledContent("Model", value: provider.modelName)
            } header: {
                Text("Details")
            } footer: {
                Text("Your API key is stored in the iOS Keychain on this device. Messages are sent only to the selected AI provider for translation or rewriting.")
            }

            Section("Developer") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developed by Stefania Izzo")
                    Text("IzzOnLine di Stefania Izzo")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                Link(destination: URL(string: "https://izzonline.it")!) {
                    Label("izzonline.it", systemImage: "globe")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").bold()
            Text(text)
        }
        .font(.callout)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
