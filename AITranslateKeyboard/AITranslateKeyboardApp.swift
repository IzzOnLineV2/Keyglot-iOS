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
/// No key → onboarding; key present → settings.
private struct RootView: View {
    @State private var isConfigured = CredentialStore.shared
        .hasAPIKey(for: AppGroupStorage.shared.selectedProvider)

    var body: some View {
        if isConfigured {
            SettingsView()
        } else {
            OnboardingView(isConfigured: $isConfigured)
        }
    }
}
