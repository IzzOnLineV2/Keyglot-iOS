import SwiftUI
import StoreKit

/// Home, the app's root screen (design 06). A product surface, not a Form of pickers: the Listen
/// hero on top, then "Your keyboard" and "Your plan" as quiet cards. Custom (BYOK) lives behind
/// "Advanced", so the home stays clean for the average user.
struct SettingsView: View {
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var languageCount = AppGroupStorage.shared.selectedLanguageIDs.count
    @State private var languages = AppGroupStorage.shared.selectedLanguages
    @State private var keyboardIsSetUp = AppGroupStorage.shared.keyboardIsSetUp

    @State private var showWelcomePreview = false
    @State private var showPro = false
    @State private var showManage = false
    @State private var showSetupSteps = false

    private let maxLanguages = Configuration.maxKeyboardLanguages

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    listenHero
                    keyboardSection
                    planSection
                    KGCard(padding: 0) {
                        Button { showWelcomePreview = true } label: {
                            SettingsRow(icon: "hand.wave.fill", title: "Show welcome again").padding(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(KGColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPro) {
                ProPaywallView(onClose: { showPro = false }).environmentObject(subscription)
            }
            .sheet(isPresented: $showSetupSteps) { setupStepsSheet }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .fullScreenCover(isPresented: $showWelcomePreview) {
                WelcomeView(onDone: { showWelcomePreview = false }).environmentObject(subscription)
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
                    Text("Press, speak, and Keyglot translates what it hears into your language.")
                        .font(KGFont.caption).foregroundStyle(Color.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward").foregroundStyle(Color.white.opacity(0.6))
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

    // MARK: - Your keyboard

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your keyboard").kgEyebrow()
            KGCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink { LanguageSelectionView() } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsRow(icon: "globe", title: "Languages",
                                        value: String(localized: "\(languageCount) of \(maxLanguages)"))
                            if !languages.isEmpty {
                                LazyVGrid(
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                                    spacing: 6
                                ) {
                                    ForEach(languages) { language in
                                        LanguageChip(flag: language.flag, name: language.name, height: 44)
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(KGColor.border)
                    keyboardStatusRow
                }
            }
        }
    }

    @ViewBuilder private var keyboardStatusRow: some View {
        if keyboardIsSetUp {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(KGColor.success)
                    .frame(width: 29, height: 29)
                    .background(KGColor.successBg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text("Keyboard is set up").font(KGFont.row).foregroundStyle(KGColor.ink)
                Spacer(minLength: 8)
                Text("Full Access on").font(KGFont.caption).foregroundStyle(KGColor.ink3)
            }
            .padding(14)
        } else {
            Button { showSetupSteps = true } label: {
                SettingsRow(icon: "keyboard", iconTint: KGColor.attention, iconBg: KGColor.attentionBg,
                            title: "Set up the keyboard").padding(14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Your plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your plan").kgEyebrow()
            KGCard(padding: 0) {
                VStack(spacing: 0) {
                    Button {
                        if subscription.isSubscribed { showManage = true } else { showPro = true }
                    } label: {
                        planProRow.padding(14)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(KGColor.border)
                    NavigationLink { AdvancedView() } label: {
                        SettingsRow(icon: "slider.horizontal.3", title: "Advanced",
                                    value: String(localized: "Use your own AI")).padding(14)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(KGColor.border)
                    NavigationLink { AboutView() } label: {
                        SettingsRow(icon: "info.circle", title: "About Keyglot").padding(14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var planProRow: some View {
        HStack(spacing: 12) {
            LogoMark(size: 29)
            VStack(alignment: .leading, spacing: 2) {
                Text("KeyGlot Pro").font(KGFont.row).foregroundStyle(KGColor.ink)
                Text(planSubtitle).font(KGFont.caption).foregroundStyle(KGColor.ink3)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(KGColor.ink3)
        }
        .contentShape(Rectangle())
    }

    private var planSubtitle: String {
        guard subscription.isSubscribed else { return String(localized: "AI included") }
        let plan = (subscription.activeProductID?.hasSuffix("yearly") ?? false)
            ? String(localized: "Yearly") : String(localized: "Monthly")
        if let date = subscription.renewalDate {
            let dateStr = date.formatted(date: .abbreviated, time: .omitted)
            return "\(plan) · \(String(localized: "renews \(dateStr)"))"
        }
        return plan
    }

    // MARK: - Setup steps sheet

    private var setupStepsSheet: some View {
        NavigationStack {
            ScrollView {
                KGCard {
                    SetupChecklist(mode: AppGroupStorage.shared.aiMode,
                                   providerName: AppGroupStorage.shared.selectedProvider.displayName)
                }
                .padding()
            }
            .background(KGColor.canvas)
            .navigationTitle("Set up the keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSetupSteps = false }
                }
            }
        }
    }

    private func refresh() {
        languageCount = AppGroupStorage.shared.selectedLanguageIDs.count
        languages = AppGroupStorage.shared.selectedLanguages
        keyboardIsSetUp = AppGroupStorage.shared.keyboardIsSetUp
    }
}

/// Step-by-step instructions for enabling the keyboard, shown in the setup sheet.
private struct SetupChecklist: View {
    let mode: AIMode
    let providerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if mode == .custom {
                step(1, "Add your \(providerName) API key in Advanced.")
            } else {
                step(1, "You're on KeyGlot, AI is included, no API key needed.")
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
