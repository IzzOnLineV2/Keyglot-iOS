import SwiftUI

/// Observable UI state for the keyboard toolbar.
///
/// Lives on the main actor because it drives SwiftUI. The view controller owns it and
/// mutates it as a translation progresses.
@MainActor
final class KeyboardState: ObservableObject {

    enum Status: Equatable {
        case idle
        /// Work in flight (translating or rewriting). The string is the progress label to show.
        case busy(String)
        case error(String)
    }

    @Published var status: Status = .idle

    /// Languages shown on the toolbar, in order — driven by the user's settings.
    @Published var languages: [TargetLanguage] = []

    /// Whether the host has granted Full Access. Network calls only work when this is true.
    @Published var hasFullAccess: Bool = true

    /// Whether an API key is configured for the selected provider. No key → buttons disabled.
    @Published var hasAPIKey: Bool = false

    /// Whether the input field currently holds text — drives the contextual idle hint
    /// (empty → "type on your keyboard first", non-empty → "tap a flag").
    @Published var hasText: Bool = false

    /// Whether to show the "switch keyboard" globe (only when other keyboards exist).
    @Published var showsNextKeyboard: Bool = true

    /// Read-only translation of a RECEIVED message the user copied to the clipboard.
    /// When non-nil, the toolbar shows a read-only panel instead of the normal buttons.
    @Published var clipboardResult: String? = nil

    /// Actions (translate/rewrite) only work with Full Access, a configured key, and no work
    /// in flight.
    var canTranslate: Bool {
        hasFullAccess && hasAPIKey && !isBusy
    }

    private var errorResetTask: Task<Void, Never>?

    /// Enter the busy state with a progress label (e.g. "Translating to Français…", "Rewriting…").
    func beginWork(_ label: String) {
        errorResetTask?.cancel()
        status = .busy(label)
    }

    func finishWork() {
        if case .busy = status { status = .idle }
    }

    /// Show a transient error banner that clears itself after a few seconds.
    func showError(_ message: String) {
        status = .error(message)
        errorResetTask?.cancel()
        errorResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if case .error = self?.status { self?.status = .idle }
        }
    }

    var isBusy: Bool {
        if case .busy = status { return true }
        return false
    }
}
