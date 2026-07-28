import SwiftUI

/// The keyboard's entire UI: a row of translation (language) buttons and a row of rewrite
/// (tone) buttons, with a transient status line for progress and errors.
///
/// A keyboard extension *replaces* the system keyboard, so this view also offers a
/// "switch keyboard" globe to let the user return to their typing keyboard.
struct ToolbarView: View {
    @ObservedObject var state: KeyboardState

    /// Invoked when a language button is tapped.
    let onSelect: (TargetLanguage) -> Void
    /// Invoked when a rewrite (tone) button is tapped.
    let onRewrite: (RewriteAction) -> Void
    /// Invoked when the "translate from clipboard" (received message) button is tapped.
    let onTranslateClipboard: () -> Void
    /// Wires the globe up to the system keyboard switcher (tap = advance, long-press = picker).
    let configureNextKeyboardButton: (UIButton) -> Void

    var body: some View {
        Group {
            if let result = state.clipboardResult {
                clipboardPanel(result)
            } else {
                mainToolbar
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private var mainToolbar: some View {
        VStack(spacing: 6) {
            statusBar
            buttonRow
            rewriteCaption
            rewriteRow
        }
    }

    // MARK: - Status

    /// Idle hint, which doubles as the "configure me" prompt when translation isn't available.
    private var idleMessage: String {
        if !state.hasFullAccess {
            return String(localized: "Enable Full Access in Settings to translate.")
        }
        if !state.hasAPIKey {
            return String(localized: "Open the Keyglot app to add your API key.")
        }
        if !state.hasText {
            return String(localized: "Tap 🌐 to type on your keyboard, then come back here and pick a language.")
        }
        return String(localized: "Tap a flag to translate your message.")
    }

    @ViewBuilder
    private var statusBar: some View {
        switch state.status {
        case .idle:
            Text(idleMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

        case .busy(let label):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                // `label` is already localized by the view controller (translate vs rewrite).
                Text(verbatim: label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .error(let message):
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.92))
                )
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        HStack(spacing: 8) {
            if state.showsNextKeyboard {
                NextKeyboardButton(configure: configureNextKeyboardButton)
                    .frame(width: 44, height: 54)
            }

            // Translate a received message the user has copied to the clipboard.
            Button {
                onTranslateClipboard()
            } label: {
                Text("📋")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Translate a received message from the clipboard"))
            .disabled(!state.canTranslate)
            .opacity(state.canTranslate ? 1 : 0.5)

            ForEach(state.languages) { language in
                Button {
                    onSelect(language)
                } label: {
                    VStack(spacing: 3) {
                        Text(language.flag)
                            .font(.system(size: 22))
                        // Native language name, tiny; shrinks so long autonyms
                        // (e.g. "العربية الفصحى", "Português") still fit on one line.
                        Text(language.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.accessibilityLabel)
                .disabled(!state.canTranslate)
                .opacity(state.canTranslate ? 1 : 0.5)
            }
        }
    }

    /// Caption between the two rows, making clear the tone buttons rewrite (same language)
    /// rather than translate. Mirrors the "Tap a flag…" status hint above the language row.
    private var rewriteCaption: some View {
        Text("Tap an action to improve the text or change the tone.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    /// The same-language rewrite actions (✨ 💼 😊 ❤️). Shares `canTranslate` — both need
    /// Full Access, a key, and no work in flight.
    private var rewriteRow: some View {
        HStack(spacing: 8) {
            ForEach(RewriteAction.all) { action in
                Button {
                    onRewrite(action)
                } label: {
                    VStack(spacing: 3) {
                        Text(action.glyph)
                            .font(.system(size: 22))
                        // Localized action name (Migliora, Improve, …); shrinks to fit.
                        Text(LocalizedStringKey(action.name))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.accessibilityLabel)
                .disabled(!state.canTranslate)
                .opacity(state.canTranslate ? 1 : 0.5)
            }
        }
    }

    /// Read-only panel showing the translation of a received message (from the clipboard).
    /// A close button dismisses it and returns to the normal toolbar.
    private func clipboardPanel(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Received message", systemImage: "tray.and.arrow.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    state.clipboardResult = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            ScrollView {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

/// A `UIButton`-backed globe that shows the system keyboard picker on long-press and
/// advances to the next keyboard on tap — the standard custom-keyboard behaviour that
/// SwiftUI alone cannot provide.
private struct NextKeyboardButton: UIViewRepresentable {
    let configure: (UIButton) -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        configure(button)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
