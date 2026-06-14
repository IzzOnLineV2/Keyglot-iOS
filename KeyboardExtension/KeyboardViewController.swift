import UIKit
import SwiftUI

/// The keyboard extension's principal class.
///
/// Hosts the SwiftUI `ToolbarView`, reads the text the user already typed (what iOS exposes
/// around the cursor), sends it to the selected AI provider, and replaces it with the result.
final class KeyboardViewController: UIInputViewController {

    private let state = KeyboardState()
    private let service = TranslationService()
    private var heightConstraint: NSLayoutConstraint?

    private static let keyboardHeight: CGFloat = 100

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        installToolbar()
        installHeightConstraint()
        updateAPIKeyAvailability()
        updateLanguages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshEnvironment()
        // Re-check in case the user changed the key or languages in the app and switched back.
        updateAPIKeyAvailability()
        updateLanguages()
        updateHasText()
    }

    /// Called by the system whenever the document's text changes — keeps `hasText` in sync so
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

    /// Keep UI-affecting environment flags in sync with the host. Only assign on change —
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

    // MARK: - Translation flow

    private func performTranslation(to language: TargetLanguage) {
        guard !state.isBusy else { return }

        guard hasFullAccess else {
            state.showError(String(localized: "Enable Full Access in Settings to translate."))
            return
        }

        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let fullText = before + after

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state.showError(String(localized: "Type a message first, then tap a language."))
            return
        }

        state.beginTranslating(language)

        Task { [weak self] in
            guard let self else { return }
            do {
                let translated = try await self.service.translate(fullText, to: language)
                self.replaceMessage(before: before, after: after, with: translated)
                self.state.finishTranslating()
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
            return String(localized: "No API key set — add your \(name) key in the Keyglot app.")
        }
        if case TranslationService.ServiceError.emptyInput = error {
            return String(localized: "Type a message first, then tap a language.")
        }
        if case let ProviderError.http(status, message) = error {
            let text = message.lowercased()
            switch status {
            case 401:
                return String(localized: "Invalid API key — open the Keyglot app and check your \(name) key.")
            case 403:
                if text.contains("credit") || text.contains("billing") {
                    return String(localized: "Billing issue — add credit to your \(name) account.")
                }
                return String(localized: "Access denied — your \(name) key isn't allowed to do this.")
            case 400:
                if text.contains("credit") {
                    return String(localized: "Out of credit — add billing to your \(name) account.")
                }
                return String(localized: "\(name) rejected the request: \(message)")
            case 404:
                return String(localized: "Model not available for your \(name) key.")
            case 429:
                return String(localized: "Too many requests — wait a few seconds and try again.")
            case 500...599:
                return String(localized: "\(name) is temporarily unavailable — try again shortly.")
            default:
                return String(localized: "\(name) error \(status): \(message)")
            }
        }
        if case ProviderError.transport = error {
            return String(localized: "No network — check your connection and that Full Access is on.")
        }
        if case ProviderError.emptyOutput = error {
            return String(localized: "\(name) returned nothing — try again.")
        }
        if case ProviderError.invalidResponse = error {
            return String(localized: "Unexpected response from \(name).")
        }
        return String(localized: "Couldn't translate: \(error.localizedDescription)")
    }
}
