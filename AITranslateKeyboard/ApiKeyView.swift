import SwiftUI

/// Enter, replace or clear the API key for a specific provider. The key is written to the
/// shared App Group so the keyboard extension can read it.
struct ApiKeyView: View {
    let provider: AIProviderType
    @Binding var hasAPIKey: Bool

    @State private var keyText: String
    @State private var isRevealed = false
    @State private var savedConfirmation = false
    @State private var saveFailed = false
    @State private var isTesting = false
    @State private var testResult = ""
    @State private var showTestResult = false
    @Environment(\.dismiss) private var dismiss

    init(provider: AIProviderType, hasAPIKey: Binding<Bool>) {
        self.provider = provider
        self._hasAPIKey = hasAPIKey
        self._keyText = State(initialValue: CredentialStore.shared.apiKey(for: provider) ?? "")
    }

    var body: some View {
        Form {
            Section {
                Group {
                    if isRevealed {
                        TextField(provider.apiKeyPlaceholder, text: $keyText)
                    } else {
                        SecureField(provider.apiKeyPlaceholder, text: $keyText)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

                Toggle("Reveal key", isOn: $isRevealed)

                Link(destination: provider.apiKeyURL) {
                    Label("Get a \(provider.displayName) API key", systemImage: "arrow.up.forward.square")
                }
            } header: {
                Text(provider.apiKeyName)
            } footer: {
                Text("Stored securely in the iOS Keychain on this device. Sent only to \(provider.displayName).")
            }

            Section {
                Button("Save") { save() }
                    .disabled(trimmedKey.isEmpty)

                Button {
                    runTest()
                } label: {
                    HStack {
                        Text("Test translation")
                        if isTesting { Spacer(); ProgressView() }
                    }
                }
                .disabled(trimmedKey.isEmpty || isTesting)

                if hasAPIKey {
                    Button("Remove key", role: .destructive) { clear() }
                }
            } footer: {
                Text("“Test” sends one short request to \(provider.displayName) and shows the exact result or error — handy to check the key, model and billing.")
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Saved", isPresented: $savedConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your \(provider.displayName) API key has been saved.")
        }
        .alert("Couldn't save the key", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The key couldn't be written to the iOS Keychain. Run the app signed with your Team (from Xcode) or on a device, then try again.")
        }
        .alert("Test result", isPresented: $showTestResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(testResult)
        }
    }

    private func runTest() {
        let key = trimmedKey
        let type = provider
        guard !key.isEmpty else { return }
        isTesting = true
        Task {
            let client = AIProviderFactory.make(type, apiKey: key)
            let language = TargetLanguage.byID("en") ?? TargetLanguage.catalog[0]
            do {
                let output = try await client.generate(
                    text: "Ciao, come stai? Spero che il viaggio stia andando bene.",
                    systemPrompt: language.prompt
                )
                testResult = String(localized: "✅ Works.\n\nTranslation:\n\(output)")
            } catch {
                testResult = String(localized: "❌ Failed.\n\n\(error.localizedDescription)")
            }
            isTesting = false
            showTestResult = true
        }
    }

    private var trimmedKey: String {
        keyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if CredentialStore.shared.setAPIKey(trimmedKey, for: provider) {
            hasAPIKey = true
            savedConfirmation = true
        } else {
            saveFailed = true
        }
    }

    private func clear() {
        CredentialStore.shared.setAPIKey(nil, for: provider)
        keyText = ""
        hasAPIKey = false
        dismiss()
    }
}
