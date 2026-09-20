import SwiftUI

/// Root screen of the companion app. The keyboard itself has no settings — everything
/// is configured here and shared via the App Group.
struct SettingsView: View {
    @State private var aiMode = AppGroupStorage.shared.aiMode
    @State private var selectedProvider = AppGroupStorage.shared.selectedProvider
    @State private var hasAPIKey = false
    @State private var languageCount = AppGroupStorage.shared.selectedLanguageIDs.count

    // Temporary dev-key field for testing KeyGlot mode before StoreKit (Step 3).
    @State private var devKey = ""
    @State private var devKeySaved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ListenView()
                    } label: {
                        Label("Listen & translate", systemImage: "mic.fill")
                    }
                } footer: {
                    Text("Press, speak, and Keyglot translates what it hears into your language.")
                }

                Section {
                    Picker("AI Mode", selection: $aiMode) {
                        Text("KeyGlot").tag(AIMode.keyglot)
                        Text("Custom").tag(AIMode.custom)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("AI Mode")
                } footer: {
                    Text(aiMode == .keyglot
                         ? "AI included. No setup required."
                         : "Use your own AI provider and API key. Requests go straight to the provider you choose.")
                }

                if aiMode == .custom {
                    Section {
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(AIProviderType.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }

                        NavigationLink {
                            ApiKeyView(provider: selectedProvider, hasAPIKey: $hasAPIKey)
                        } label: {
                            LabeledContent("API Key") {
                                Text(hasAPIKey ? LocalizedStringKey("Configured") : LocalizedStringKey("Not set"))
                                    .foregroundStyle(hasAPIKey ? .green : .red)
                            }
                        }
                    } header: {
                        Text("AI Provider")
                    } footer: {
                        Text("Default is Claude Sonnet for natural, native-sounding translations. Each provider stores its own API key.")
                    }
                } else {
                    // Temporary: dev-key entry to exercise the KeyGlot backend before subscriptions.
                    Section {
                        TextField("Dev key", text: $devKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        Button("Save dev key") {
                            devKeySaved = CredentialStore.shared.setSecret(
                                devKey, account: KeyGlotSession.devKeyAccount)
                        }
                        .disabled(devKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if devKeySaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.footnote)
                        }
                    } header: {
                        Text("KeyGlot (dev)")
                    } footer: {
                        Text("Temporary: paste the backend dev key to test KeyGlot mode on this device. Removed when subscriptions ship.")
                    }
                }

                Section {
                    NavigationLink {
                        LanguageSelectionView()
                    } label: {
                        LabeledContent("Languages") {
                            Text("\(languageCount) shown")
                        }
                    }
                } header: {
                    Text("Keyboard")
                } footer: {
                    Text("Choose which languages appear on the keyboard (up to \(Configuration.maxKeyboardLanguages)). The source language is detected automatically.")
                }

                Section("Setup") {
                    SetupChecklist(mode: aiMode, providerName: selectedProvider.displayName)
                }

                Section {
                    NavigationLink("About") { AboutView() }
                }
            }
            .navigationTitle("Keyglot")
            .onChange(of: aiMode) { _, newValue in
                AppGroupStorage.shared.aiMode = newValue
                refresh()
            }
            .onChange(of: selectedProvider) { _, newValue in
                AppGroupStorage.shared.selectedProvider = newValue
                refresh()
            }
            .onAppear(perform: refresh)
        }
    }

    private func refresh() {
        hasAPIKey = CredentialStore.shared.hasAPIKey(for: selectedProvider)
        languageCount = AppGroupStorage.shared.selectedLanguageIDs.count
        if devKey.isEmpty {
            devKey = CredentialStore.shared.secret(KeyGlotSession.devKeyAccount) ?? ""
        }
    }
}

/// Step-by-step instructions for enabling the keyboard, shown inline in Settings.
private struct SetupChecklist: View {
    let mode: AIMode
    let providerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if mode == .custom {
                step(1, "Enter your \(providerName) API key above.")
            } else {
                step(1, "You're on KeyGlot — AI is included, no API key needed.")
            }
            step(2, "Open iOS Settings → General → Keyboard → Keyboards → Add New Keyboard… and add “Keyglot”.")
            step(3, "Tap “Keyglot” in that list and turn on Allow Full Access (required for network access).")
            step(4, "In any chat, tap 🌐 to switch to the Keyglot keyboard, then tap a language.")
        }
        .font(.callout)
        .padding(.vertical, 4)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
        }
    }
}

#Preview {
    SettingsView()
}
