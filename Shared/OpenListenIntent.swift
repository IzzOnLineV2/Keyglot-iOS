import AppIntents

/// Run from the Keyglot widget: opens the app and asks it to jump straight into
/// "Listen & translate". The app reads `AppGroupStorage.pendingListen` on launch/foreground.
struct OpenListenIntent: AppIntent {
    static var title: LocalizedStringResource { "Listen & translate" }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        AppGroupStorage.shared.pendingListen = true
        return .result()
    }
}
