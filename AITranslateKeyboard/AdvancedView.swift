import SwiftUI

/// "Advanced" (design 06). Where the AI comes from, and, for Custom mode, the provider + keys.
/// Custom lives here, two taps from the home and mentioned nowhere else, so the home stays a
/// clean product surface while BYOK stays fully available.
struct AdvancedView: View {
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var aiMode = AppGroupStorage.shared.aiMode
    @State private var selectedProvider = AppGroupStorage.shared.selectedProvider
    @State private var hasAPIKey = false
    @State private var hasGeminiKey = false
    @State private var showPro = false
#if DEBUG
    @State private var devKey = ""
    @State private var devKeySaved = false
#endif

    private var isCustom: Bool { aiMode == .custom }

    /// Selecting KeyGlot requires Pro: without a subscription, tapping it opens the paywall instead
    /// of switching (you can't use the included AI you don't have).
    private var modeBinding: Binding<AIMode> {
        Binding(
            get: { aiMode },
            set: { newValue in
                if newValue == .keyglot && !subscription.isSubscribed {
                    showPro = true
                } else {
                    aiMode = newValue
                }
            }
        )
    }

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    modeSection
                    if isCustom { customSection }
#if DEBUG
                    devKeyCard
#endif
                }
                .padding()
                .animation(.easeInOut(duration: 0.2), value: isCustom)
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPro) {
            ProPaywallView(onClose: {
                showPro = false
                aiMode = AppGroupStorage.shared.aiMode   // reflect the switch a purchase makes
            })
            .environmentObject(subscription)
        }
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
                    SegmentedModePicker(mode: modeBinding)
                    if subscription.isSubscribed && aiMode == .custom {
                        proNudge
                    }
                    if aiMode == .keyglot && !subscription.isSubscribed {
                        needsProNudge
                    }
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

    /// Pro user currently on Custom: nudge them to use what they pay for.
    private var proNudge: some View {
        Button { aiMode = .keyglot } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(KGColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're on Pro").font(KGFont.caption.weight(.semibold)).foregroundStyle(KGColor.ink)
                    Text("Switch to KeyGlot to use the AI included in your plan.")
                        .font(KGFont.caption).foregroundStyle(KGColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.accentTint, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// KeyGlot selected but no subscription: KeyGlot needs Pro.
    private var needsProNudge: some View {
        Button { showPro = true } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(KGColor.attention)
                VStack(alignment: .leading, spacing: 2) {
                    Text("KeyGlot needs Pro").font(KGFont.caption.weight(.semibold)).foregroundStyle(KGColor.ink)
                    Text("Subscribe to use the included AI, or switch to Custom with your own key.")
                        .font(KGFont.caption).foregroundStyle(KGColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.attentionBg, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
        }
        .buttonStyle(.plain)
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
        .transition(.opacity.combined(with: .move(edge: .top)))
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
    NavigationStack { AdvancedView() }.environmentObject(SubscriptionManager())
}
