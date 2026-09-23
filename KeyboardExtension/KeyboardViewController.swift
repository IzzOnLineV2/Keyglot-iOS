import UIKit
import SwiftUI
import Combine

/// The keyboard extension's principal class.
///
/// Hosts the SwiftUI `ToolbarView`, reads the text the user already typed (what iOS exposes
/// around the cursor), sends it to the selected AI provider, and replaces it with the result.
final class KeyboardViewController: UIInputViewController {

    private let state = KeyboardState()
    private let service = TranslationService()
    private var heightConstraint: NSLayoutConstraint?
    private var cancellables = Set<AnyCancellable>()

    /// The message before the last translation replaced it, so "Undo" can put it back.
    private var lastOriginal: String?

    // Status hint + language row (flag + name) + rewrite caption + tone row (glyph + name).
    private static let keyboardHeight: CGFloat = 200

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        installToolbar()
        installHeightConstraint()
        observeClipboardPanel()
        updateAPIKeyAvailability()
        updateLanguages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshEnvironment()
        // Full Access is required to reach the shared App Group, so recording here also tells the
        // app the keyboard is installed and working (drives the "Keyboard is set up" status).
        if hasFullAccess { AppGroupStorage.shared.recordKeyboardActive() }
        // Re-check in case the user changed the key or languages in the app and switched back.
        updateAPIKeyAvailability()
        updateLanguages()
        updateHasText()
    }

    /// Called by the system whenever the document's text changes, keeps `hasText` in sync so
    /// the idle hint can tell the user to type on their normal keyboard first.
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateHasText()
    }

    private func updateHasText() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let has = !(before + after).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if state.hasText != has {
            state.hasText = has
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        refreshEnvironment()
    }

    /// Keep UI-affecting environment flags in sync with the host. Only assign on change -
    /// this runs on every layout pass and `@Published` fires regardless of equality.
    private func refreshEnvironment() {
        if state.hasFullAccess != hasFullAccess {
            state.hasFullAccess = hasFullAccess
        }
        if state.showsNextKeyboard != needsInputModeSwitchKey {
            state.showsNextKeyboard = needsInputModeSwitchKey
        }
    }

    /// Reads the shared Keychain for a key matching the selected provider, so the toolbar can
    /// disable the language buttons when none is configured. Kept out of the layout pass.
    private func updateAPIKeyAvailability() {
        let available = CredentialStore.shared.hasAPIKey(for: AppGroupStorage.shared.selectedProvider)
        if state.hasAPIKey != available {
            state.hasAPIKey = available
        }
    }

    /// Loads the user's chosen languages so the toolbar shows exactly those buttons.
    private func updateLanguages() {
        let languages = AppGroupStorage.shared.selectedLanguages
        if state.languages != languages {
            state.languages = languages
        }
    }

    // MARK: - Setup

    private func installToolbar() {
        let toolbar = ToolbarView(
            state: state,
            onSelect: { [weak self] language in
                self?.performTranslation(to: language)
            },
            onRewrite: { [weak self] action in
                self?.performRewrite(action)
            },
            onTranslateClipboard: { [weak self] in
                self?.performClipboardTranslation()
            },
            onUndo: { [weak self] in
                self?.performUndo()
            },
            configureNextKeyboardButton: { [weak self] button in
                guard let self else { return }
                button.addTarget(
                    self,
                    action: #selector(self.handleInputModeList(from:with:)),
                    for: .allTouchEvents
                )
            }
        )

        let hosting = UIHostingController(rootView: toolbar)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hosting)
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)
    }

    private func installHeightConstraint() {
        let constraint = view.heightAnchor.constraint(equalToConstant: Self.keyboardHeight)
        // Just below required so it never conflicts with the system's layout pass.
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        heightConstraint = constraint
    }

    /// Grow the keyboard while the "translate a received message" panel is open, so a long message
    /// is comfortable to read, then shrink back to the normal bar height when it's closed.
    private func observeClipboardPanel() {
        state.$clipboardResult
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in self?.setExpanded(expanded) }
            .store(in: &cancellables)
    }

    private func setExpanded(_ expanded: Bool) {
        guard let heightConstraint else { return }
        let target = expanded ? expandedHeight : Self.keyboardHeight
        guard heightConstraint.constant != target else { return }
        heightConstraint.constant = target
        UIView.animate(withDuration: 0.22) { self.view.superview?.layoutIfNeeded(); self.view.layoutIfNeeded() }
    }

    /// About 55% of the screen (capped), enough to read a long received message comfortably.
    private var expandedHeight: CGFloat {
        let screenH = view.window?.screen.bounds.height ?? 800
        return min(max(Self.keyboardHeight, screenH * 0.55), 470)
    }

    // MARK: - Translation & rewrite flow

    private func performTranslation(to language: TargetLanguage) {
        let label = String(localized: "Translating to \(language.name)…")
        runAction(label: label, languageID: language.id) { service, text in
            try await service.translate(text, to: language)
        }
    }

    private func performRewrite(_ action: RewriteAction) {
        let label = String(localized: "Rewriting…")
        runAction(label: label) { service, text in
            try await service.rewrite(text, as: action)
        }
    }

    /// Translate a RECEIVED message the user copied to the clipboard, into their own language,
    /// and show it read-only. Unlike translate/rewrite, this never touches the text field.
    private func performClipboardTranslation() {
        guard !state.isBusy else { return }

        guard hasFullAccess else {
            state.showError(String(localized: "Enable Full Access in Settings to translate."))
            return
        }

        // `hasStrings` doesn't require the paste permission, so we can rule out an empty clipboard
        // without triggering the prompt.
        guard UIPasteboard.general.hasStrings else {
            state.showError(String(localized: "Copy a message first, then tap the clipboard button."))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            // Reading `.string` shows the paste permission prompt and returns nil until the user
            // allows; poll briefly so a single tap works once they tap Allow.
            guard let clip = await self.readClipboardWithRetry() else {
                self.state.showError(String(localized: "Copy a message first, then tap the clipboard button."))
                return
            }
            self.state.beginWork(String(localized: "Translating…"))
            do {
                let result = try await self.service.translate(clip, to: .deviceLanguage)
                self.state.clipboardResult = result
                self.state.finishWork()
                AppGroupStorage.shared.recordUse()
            } catch {
                self.state.showError(self.bannerMessage(for: error))
            }
        }
    }

    /// Read the clipboard, retrying for a few seconds so the flow completes on one tap after the
    /// user grants the paste prompt. Returns nil if nothing readable appears (denied or empty).
    private func readClipboardWithRetry() async -> String? {
        for _ in 0..<16 {   // ~4.8s at 0.3s intervals
            if let s = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty {
                return s
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return nil
    }

    /// Put the user's original words back after a translation (the "Undo" pill).
    private func performUndo() {
        guard let original = lastOriginal else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        replaceMessage(before: before, after: after, with: original)
        lastOriginal = nil
        state.finishWork()
    }

    /// Shared flow for both translation and rewriting: validate, read the exposed text, run the
    /// provider call, and replace the message in place. On failure the original text is untouched.
    private func runAction(
        label: String,
        languageID: String? = nil,
        _ work: @escaping @Sendable (TranslationService, String) async throws -> String
    ) {
        guard !state.isBusy else { return }

        guard hasFullAccess else {
            state.showError(String(localized: "Enable Full Access in Settings to translate."))
            return
        }

        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let fullText = before + after

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state.showError(String(localized: "Type a message first, then tap a button."))
            return
        }

        state.beginWork(label)
        state.activeLanguageID = languageID

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await work(self.service, fullText)
                self.replaceMessage(before: before, after: after, with: result)
                self.lastOriginal = fullText
                if let languageID {
                    self.state.showReplaced(languageID: languageID)
                } else {
                    self.state.finishWork()
                }
                AppGroupStorage.shared.recordUse()
            } catch {
                // On failure we leave the user's original text untouched.
                self.state.showError(self.bannerMessage(for: error))
            }
        }
    }

    /// Replace the current message (the text iOS exposes around the cursor) with `newText`,
    /// leaving the cursor at the end.
    private func replaceMessage(before: String, after: String, with newText: String) {
        let proxy = textDocumentProxy

        // Move the cursor to the end of the exposed text so deleteBackward clears it.
        if !after.isEmpty {
            proxy.adjustTextPosition(byCharacterOffset: (after as NSString).length)
        }

        let deleteCount = (before + after).count
        for _ in 0..<deleteCount {
            proxy.deleteBackward()
        }

        proxy.insertText(newText)
    }

    private func bannerMessage(for error: Error) -> String {
        let name = AppGroupStorage.shared.selectedProvider.displayName

        if error is AIProviderError {
            return String(localized: "No API key set, add your \(name) key in the Keyglot app.")
        }
        if case TranslationService.ServiceError.emptyInput = error {
            return String(localized: "Type a message first, then tap a button.")
        }
        if case let ProviderError.http(status, message) = error {
            let text = message.lowercased()
            switch status {
            case 401:
                return String(localized: "Invalid API key, open the Keyglot app and check your \(name) key.")
            case 403:
                if text.contains("credit") || text.contains("billing") {
                    return String(localized: "Billing issue, add credit to your \(name) account.")
                }
                return String(localized: "Access denied, your \(name) key isn't allowed to do this.")
            case 400:
                if text.contains("credit") {
                    return String(localized: "Out of credit, add billing to your \(name) account.")
                }
                return String(localized: "\(name) rejected the request: \(message)")
            case 404:
                return String(localized: "Model not available for your \(name) key.")
            case 429:
                return String(localized: "Too many requests, wait a few seconds and try again.")
            case 500...599:
                return String(localized: "\(name) is temporarily unavailable, try again shortly.")
            default:
                return String(localized: "\(name) error \(status): \(message)")
            }
        }
        if case ProviderError.transport = error {
            return String(localized: "No network, check your connection and that Full Access is on.")
        }
        if case ProviderError.emptyOutput = error {
            return String(localized: "\(name) returned nothing, try again.")
        }
        if case ProviderError.invalidResponse = error {
            return String(localized: "Unexpected response from \(name).")
        }
        return String(localized: "Couldn't translate: \(error.localizedDescription)")
    }
}
