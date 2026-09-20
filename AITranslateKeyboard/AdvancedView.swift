import SwiftUI

/// "Advanced" (design 06). Where the AI comes from, and, for Custom mode, the provider + keys.
/// Custom lives here, two taps from the home and mentioned nowhere else, so the home stays a
/// clean product surface while BYOK stays fully available.
struct AdvancedView: View {
    @State private var aiMode = AppGroupStorage.shared.aiMode
    @State private var selectedProvider = AppGroupStorage.shared.selectedProvider
    @State private var hasAPIKey = false
    @State private var hasGeminiKey = false
#if DEBUG
    @State private var devKey = ""
    @State private var devKeySaved = false
#endif

    private var isCustom: Bool { aiMode == .custom }

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    modeSection
                    customSection
#if DEBUG
                    devKeyCard
#endif
                }
                .padding()
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: aiMode) { _, newValue in
            AppGroupStorage.shared.aiMode = newValue
        }
        .onChange(of: selectedProvider) { _, newValue in
            AppGroupStorage.shared.selectedProvider = newValue
            refresh()
        }
        .onAppear(perform: refresh)
    }

    // MARK: - Where the AI comes from

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where the AI comes from").kgEyebrow()
            KGCard {
                VStack(alignment: .leading, spacing: 14) {
                    SegmentedModePicker(mode: $aiMode)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("**KeyGlot:** AI included with Pro, nothing to configure.")
                        Text("**Custom:** free forever, but you bring your own provider and key. Requests go straight from your phone to them.")
                    }
                    .font(KGFont.caption).foregroundStyle(KGColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Custom provider (dimmed until Custom is on)

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom provider").kgEyebrow()
            KGCard(padding: 0) {
                VStack(spacing: 0) {
                    Menu {
                        ForEach(AIProviderType.allCases) { provider in
                            Button(provider.displayName) { selectedProvider = provider }
                        }
                    } label: {
                        SettingsRow(icon: "cpu", title: "Provider", value: selectedProvider.displayName).padding(14)
                    }
                    Divider().overlay(KGColor.border)
                    NavigationLink {
                        ApiKeyView(provider: selectedProvider, hasAPIKey: $hasAPIKey)
                    } label: {
                        SettingsRow(
                            icon: "key.fill",
                            iconTint: hasAPIKey ? KGColor.success : KGColor.error,
                            iconBg: hasAPIKey ? KGColor.successBg : KGColor.errorBg,
                            title: "API Key",
                            value: hasAPIKey ? String(localized: "Configured") : String(localized: "Not set")
                        ).padding(14)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(KGColor.border)
                    NavigationLink {
                        ApiKeyView(provider: .gemini, hasAPIKey: $hasGeminiKey)
                    } label: {
                        SettingsRow(
                            icon: "waveform",
                            iconTint: hasGeminiKey ? KGColor.success : KGColor.ink2,
                            iconBg: hasGeminiKey ? KGColor.successBg : KGColor.fill,
                            title: "Voice notes key",
                            value: "Gemini"
                        ).padding(14)
                    }
                    .buttonStyle(.plain)
                }
            }

            Label {
                Text("Keys are stored in the iOS Keychain on this device and shared only with the Keyglot keyboard. Keyglot never sees them.")
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(KGFont.caption).foregroundStyle(KGColor.ink3)
            .padding(.horizontal, 2)
        }
        .opacity(isCustom ? 1 : 0.5)
        .allowsHitTesting(isCustom)
    }

#if DEBUG
    // Dev-only: exercise the KeyGlot backend via the dev-key path (backend DEV_MODE=1). Compiled
    // out of Release; the real KeyGlot path is StoreKit + App Attest.
    private var devKeyCard: some View {
        KGCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("KeyGlot dev key (debug only)").font(KGFont.caption).foregroundStyle(KGColor.ink3)
                HStack {
                    TextField("Dev key", text: $devKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.system(.footnote, design: .monospaced))
                    Button("Save") {
                        devKeySaved = CredentialStore.shared.setSecret(devKey, account: KeyGlotSession.devKeyAccount)
                    }
                    .buttonStyle(.borderless)
                    .disabled(devKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if devKeySaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(KGColor.success)
                }
            }
        }
        .onAppear { if devKey.isEmpty { devKey = CredentialStore.shared.secret(KeyGlotSession.devKeyAccount) ?? "" } }
    }
#endif

    private func refresh() {
        hasAPIKey = CredentialStore.shared.hasAPIKey(for: selectedProvider)
        hasGeminiKey = CredentialStore.shared.hasAPIKey(for: .gemini)
    }
}

#Preview {
    NavigationStack { AdvancedView() }
}
