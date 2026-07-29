import SwiftUI

/// Root screen of the companion app. The keyboard itself has no settings — everything
/// is configured here and shared via the App Group.
struct SettingsView: View {
    @State private var selectedProvider = AppGroupStorage.shared.selectedProvider
    @State private var hasAPIKey = false
    @State private var languageCount = AppGroupStorage.shared.selectedLanguageIDs.count

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
                    SetupChecklist(providerName: selectedProvider.displayName)
                }

                Section {
                    NavigationLink("About") { AboutView() }
                }
            }
            .navigationTitle("Keyglot")
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
    }
}

/// Step-by-step instructions for enabling the keyboard, shown inline in Settings.
private struct SetupChecklist: View {
    let providerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            step(1, "Enter your \(providerName) API key above.")
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
