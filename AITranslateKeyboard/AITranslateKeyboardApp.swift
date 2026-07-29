import SwiftUI

@main
struct AITranslateKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Gates the app on having an API key for the selected provider (Claude by default).
/// No key → onboarding; key present → settings. Also handles:
/// - the widget's "listen" request (present the Listen screen when `pendingListen` is set), and
/// - the "support Keyglot" reminder (a dismissible paywall after a few uses, until purchased).
private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = StoreManager()
    @State private var isConfigured = CredentialStore.shared
        .hasAPIKey(for: AppGroupStorage.shared.selectedProvider)
    @State private var showListen = false
    @State private var showPaywall = false
    @State private var paywallShownThisLaunch = false

    /// Show the reminder after this many translations.
    private let paywallThreshold = 6

    var body: some View {
        Group {
            if isConfigured {
                SettingsView()
            } else {
                OnboardingView(isConfigured: $isConfigured)
            }
        }
        .fullScreenCover(isPresented: $showListen) {
            NavigationStack {
                ListenView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showListen = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store) { showPaywall = false }
        }
        .task {
            await store.load()
            maybeShowPaywall()
        }
        .onAppear(perform: consumePendingListen)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumePendingListen()
                maybeShowPaywall()
            }
        }
    }

    private func consumePendingListen() {
        guard AppGroupStorage.shared.pendingListen else { return }
        AppGroupStorage.shared.pendingListen = false
        showListen = true
    }

    /// At most once per launch, and only if not yet a supporter and past the threshold.
    private func maybeShowPaywall() {
        guard !store.isSupporter,
              !paywallShownThisLaunch,
              !showListen,
              AppGroupStorage.shared.useCount >= paywallThreshold else { return }
        paywallShownThisLaunch = true
        showPaywall = true
    }
}
