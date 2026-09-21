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
    @StateObject private var subscription = SubscriptionManager()
    @State private var showWelcome = !AppGroupStorage.shared.hasSeenOnboarding
    @State private var showListen = false
    @State private var showPaywall = false
    @State private var paywallShownThisLaunch = false

    /// Show the reminder after this many translations.
    private let paywallThreshold = 10

    var body: some View {
        Group {
            if showWelcome {
                WelcomeView(onDone: {
                    AppGroupStorage.shared.hasSeenOnboarding = true
                    withAnimation { showWelcome = false }
                })
            } else {
                // Always land on the Home after onboarding. Configuration (Custom key or Pro) lives
                // in Advanced/Pro; the keyboard guides the user when a key is missing. No full screen
                // gate that could trap a user (e.g. reinstalling with a leftover Keychain key).
                SettingsView()
            }
        }
        .environmentObject(subscription)
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
            await subscription.load()
            await refreshKeyGlotSessionIfSubscribed()
            maybeShowPaywall()
        }
        .onAppear(perform: consumePendingListen)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumePendingListen()
                maybeShowPaywall()
                Task { await refreshKeyGlotSessionIfSubscribed() }
            }
        }
    }

    /// While subscribed and in KeyGlot mode, exchange the StoreKit JWS for a fresh session token
    /// (stored in the shared Keychain) so the keyboard/share extensions can call the backend.
    private func refreshKeyGlotSessionIfSubscribed() async {
        guard AppGroupStorage.shared.aiMode == .keyglot else { return }
        if let jws = await subscription.currentEntitlementJWS() {
            _ = try? await KeyGlotSession().exchange(jws: jws)
        }
    }

    private func consumePendingListen() {
        guard AppGroupStorage.shared.pendingListen else { return }
        AppGroupStorage.shared.pendingListen = false
        showListen = true
    }

    /// At most once per launch, past the threshold, and never for supporters or Pro subscribers.
    private func maybeShowPaywall() {
        guard !store.isSupporter,
              !subscription.isSubscribed,
              !paywallShownThisLaunch,
              !showListen,
              AppGroupStorage.shared.useCount >= paywallThreshold else { return }
        paywallShownThisLaunch = true
        showPaywall = true
    }
}
