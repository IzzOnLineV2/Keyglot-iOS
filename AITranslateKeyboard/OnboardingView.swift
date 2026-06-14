import SwiftUI

/// Minimal first-run flow. Until a key for the chosen provider is saved, the app shows this
/// screen instead of the settings — translation is gated on having a key.
struct OnboardingView: View {
    /// The host (`RootView`) flips this to `true` once a key is saved.
    @Binding var isConfigured: Bool

    @State private var provider = AppGroupStorage.shared.selectedProvider
    @State private var keyText = ""
    @State private var isRevealed = false
    @State private var saveFailed = false
    @FocusState private var keyFieldFocused: Bool

    private var trimmedKey: String {
        keyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("👋")
                        .font(.system(size: 44))
                    Text("Keyglot")
                        .font(.largeTitle.bold())
                    Text("AI Message Translator")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Type in any language and replace your message with a natural translation — right inside WhatsApp, no copy/paste.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Provider", selection: $provider) {
                        ForEach(AIProviderType.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)

                    Label("Add your \(provider.displayName) API key to get started.",
                          systemImage: "key.fill")
                        .font(.headline)

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
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .focused($keyFieldFocused)

                    Toggle("Reveal key", isOn: $isRevealed)
                        .font(.subheadline)

                    Link(destination: provider.apiKeyURL) {
                        Label("Get a \(provider.displayName) API key", systemImage: "arrow.up.forward.square")
                            .font(.subheadline)
                    }

                    Text("Stored securely in the iOS Keychain on this device — never in plain settings, and shared only with the keyboard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    saveAndContinue()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedKey.isEmpty)
            }
            .padding(24)
        }
        .onAppear {
            keyText = CredentialStore.shared.apiKey(for: provider) ?? ""
            keyFieldFocused = true
        }
        .onChange(of: provider) { _, newProvider in
            // Show the key already saved for the newly-selected provider (usually empty).
            keyText = CredentialStore.shared.apiKey(for: newProvider) ?? ""
        }
        .alert("Couldn't save the key", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The key couldn't be written to the iOS Keychain. Run the app signed with your Team (from Xcode) or on a device, then try again.")
        }
    }

    private func saveAndContinue() {
        guard !trimmedKey.isEmpty else { return }
        AppGroupStorage.shared.selectedProvider = provider
        if CredentialStore.shared.setAPIKey(trimmedKey, for: provider) {
            isConfigured = true
        } else {
            saveFailed = true
        }
    }
}

#Preview {
    OnboardingView(isConfigured: .constant(false))
}
