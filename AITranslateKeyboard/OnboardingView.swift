import SwiftUI

/// First-run flow for Custom (BYOK) users: until a key for the chosen provider is saved, the app
/// shows this instead of the settings. (KeyGlot-mode installs skip straight to the home.)
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
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        LogoMark(size: 56)
                        Text("Understand every message. Answer in your words.")
                            .font(KGFont.serif(34, style: .largeTitle))
                            .foregroundStyle(KGColor.ink)
                        Text("Type in any language and replace your message with a natural translation — right inside WhatsApp, no copy/paste.")
                            .font(KGFont.body).foregroundStyle(KGColor.ink2)
                    }

                    KGCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add your API key").kgEyebrow(KGColor.accent)
                            Menu {
                                ForEach(AIProviderType.allCases) { p in Button(p.displayName) { provider = p } }
                            } label: {
                                SettingsRow(icon: "cpu", title: "Provider", value: provider.displayName)
                            }

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
                            .background(KGColor.fill, in: RoundedRectangle(cornerRadius: KGRadius.sm, style: .continuous))
                            .focused($keyFieldFocused)

                            Toggle("Reveal key", isOn: $isRevealed)
                                .font(KGFont.caption).tint(KGColor.accent)

                            Link(destination: provider.apiKeyURL) {
                                Label("Get a \(provider.displayName) API key", systemImage: "arrow.up.forward.square")
                                    .font(KGFont.caption).foregroundStyle(KGColor.accent)
                            }

                            Text("Stored in the iOS Keychain on this device — shared only with the keyboard.")
                                .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                        }
                    }

                    Button("Get Started") { saveAndContinue() }
                        .buttonStyle(.kgPrimary)
                        .disabled(trimmedKey.isEmpty)
                        .opacity(trimmedKey.isEmpty ? 0.5 : 1)
                }
                .padding(24)
            }
        }
        .onAppear {
            keyText = CredentialStore.shared.apiKey(for: provider) ?? ""
            keyFieldFocused = true
        }
        .onChange(of: provider) { _, newProvider in
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
