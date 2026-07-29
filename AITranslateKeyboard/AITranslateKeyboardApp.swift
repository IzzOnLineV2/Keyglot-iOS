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
/// No key → onboarding; key present → settings. Also handles the widget's "listen" request:
/// when the widget's App Intent set `pendingListen`, present the Listen screen on launch.
private struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfigured = CredentialStore.shared
        .hasAPIKey(for: AppGroupStorage.shared.selectedProvider)
    @State private var showListen = false

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
        .onAppear(perform: consumePendingListen)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingListen() }
        }
    }

    private func consumePendingListen() {
        guard AppGroupStorage.shared.pendingListen else { return }
        AppGroupStorage.shared.pendingListen = false
        showListen = true
    }
}
