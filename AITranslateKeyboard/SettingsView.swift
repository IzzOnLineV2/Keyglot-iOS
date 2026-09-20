import SwiftUI
import StoreKit

/// Home / settings — the app's root screen (the keyboard has no settings of its own). Redesigned
/// as a warm canvas with a Listen hero, the AI-mode toggle, and grouped cards.
struct SettingsView: View {
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var aiMode = AppGroupStorage.shared.aiMode
    @State private var selectedProvider = AppGroupStorage.shared.selectedProvider
    @State private var hasAPIKey = false
    @State private var languageCount = AppGroupStorage.shared.selectedLanguageIDs.count

    // Temporary dev-key field for testing KeyGlot mode before StoreKit (Step 3).
    @State private var devKey = ""
    @State private var devKeySaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    listenHero
                    aiModeSection
                    if aiMode == .custom { customSection } else { keyglotSection }
                    keyboardSection
                    aboutSection
                }
                .padding()
            }
            .background(KGColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Header + hero

    private var header: some View {
        HStack(alignment: .center) {
            Text("Keyglot").font(KGFont.hero).foregroundStyle(KGColor.ink)
            Spacer()
            if subscription.isSubscribed { ProBadge() }
        }
    }

    private var listenHero: some View {
        NavigationLink { ListenView() } label: {
            HStack(spacing: 14) {
                Circle().fill(KGGradient.diagonal).frame(width: 56, height: 56)
                    .overlay(Image(systemName: "mic.fill").font(.system(size: 22)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Listen & translate").font(KGFont.result).foregroundStyle(.white)
                    Text("Press, speak, and hear it back in your language.")
                        .font(KGFont.caption).foregroundStyle(Color.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").foregroundStyle(Color.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(hex: 0x1B1725), Color(hex: 0x241C36)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: KGRadius.hero, style: .continuous)
            )
            .kgShadow(.card)
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Mode

    private var aiModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Mode").kgEyebrow()
            KGCard {
                VStack(alignment: .leading, spacing: 12) {
                    SegmentedModePicker(mode: $aiMode)
                    Text(aiMode == .keyglot
                         ? "AI included. No setup required."
                         : "Use your own AI provider and API key. Requests go straight to the provider you choose.")
                        .font(KGFont.caption).foregroundStyle(KGColor.ink2)
                }
            }
        }
    }

    // MARK: - Custom (BYOK)

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI Provider").kgEyebrow()
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
                }
            }
        }
    }

    // MARK: - KeyGlot (managed)

    private var keyglotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KeyGlot Pro").kgEyebrow()
            KGCard {
                if subscription.isSubscribed {
                    Label("KeyGlot Pro is active", systemImage: "checkmark.seal.fill")
                        .font(KGFont.row).foregroundStyle(KGColor.success)
                } else if subscription.products.isEmpty {
                    Text("Loading plans…").font(KGFont.row).foregroundStyle(KGColor.ink2)
                } else {
                    VStack(spacing: 12) {
                        ForEach(subscription.products, id: \.id) { product in
                            Button { Task { try? await subscription.purchase(product) } } label: {
                                HStack {
                                    Text(product.displayName.isEmpty ? product.id : product.displayName)
                                    Spacer()
                                    Text(product.displayPrice)
                                }
                            }
                            .buttonStyle(.kgPrimary)
                        }
                        Button("Restore purchases") { Task { await subscription.restore() } }
                            .font(KGFont.caption).foregroundStyle(KGColor.ink2)
                    }
                }
            }

            // Temporary: dev-key entry to exercise the KeyGlot backend before subscriptions ship.
            KGCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("KeyGlot dev key (temporary)").font(KGFont.caption).foregroundStyle(KGColor.ink3)
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
        }
    }

    // MARK: - Keyboard

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your keyboard").kgEyebrow()
            KGCard(padding: 0) {
                NavigationLink { LanguageSelectionView() } label: {
                    SettingsRow(icon: "globe", title: "Languages", value: String(localized: "\(languageCount) shown")).padding(14)
                }
                .buttonStyle(.plain)
            }
            KGCard {
                SetupChecklist(mode: aiMode, providerName: selectedProvider.displayName)
            }
        }
    }

    private var aboutSection: some View {
        KGCard(padding: 0) {
            NavigationLink { AboutView() } label: {
                SettingsRow(icon: "info.circle", title: "About Keyglot", showChevron: true).padding(14)
            }
            .buttonStyle(.plain)
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

/// Step-by-step instructions for enabling the keyboard, shown inline in the setup card.
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
            step(2, "iOS Settings → General → Keyboard → Keyboards → add “Keyglot”.")
            step(3, "Tap “Keyglot” and turn on Allow Full Access (needed for network).")
            step(4, "In any chat, tap 🌐 to switch to Keyglot, then tap a language.")
        }
        .font(KGFont.caption)
        .foregroundStyle(KGColor.ink2)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(KGColor.accent))
            Text(text).foregroundStyle(KGColor.ink)
        }
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionManager())
}
