import SwiftUI

/// The keyboard's entire UI: a status line, a row of translation (language) chips, a row of
/// rewrite (tone) actions, and a utility row (switch-keyboard globe + "translate what they sent").
///
/// A keyboard extension *replaces* the system keyboard, so this view also offers a
/// "switch keyboard" globe to let the user return to their typing keyboard.
struct ToolbarView: View {
    @ObservedObject var state: KeyboardState

    /// Invoked when a language chip is tapped.
    let onSelect: (TargetLanguage) -> Void
    /// Invoked when a rewrite (tone) action is tapped.
    let onRewrite: (RewriteAction) -> Void
    /// Invoked when the "translate what they sent" (clipboard) action is tapped.
    let onTranslateClipboard: () -> Void
    /// Invoked when the "Undo" pill is tapped (restore the user's original message).
    let onUndo: () -> Void
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
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(KGColor.canvas)
    }

    private var mainToolbar: some View {
        VStack(spacing: 6) {
            statusBar
            languageRow
            toneRow
            utilityRow
        }
    }

    // MARK: - Status

    private var idleMessage: String {
        if !state.hasFullAccess {
            return String(localized: "Enable Full Access in Settings to translate.")
        }
        if !state.hasAPIKey {
            return String(localized: "Open the Keyglot app to add your API key.")
        }
        if !state.hasText {
            return String(localized: "Type your message, then pick a language.")
        }
        return String(localized: "Tap a language to replace your message.")
    }

    @ViewBuilder
    private var statusBar: some View {
        switch state.status {
        case .idle:
            Text(idleMessage)
                .font(KGFont.caption)
                .foregroundStyle(KGColor.ink2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 20)

        case .busy(let label):
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(KGColor.accent)
                Text(verbatim: label)
                    .font(KGFont.caption)
                    .foregroundStyle(KGColor.ink2)
            }
            .frame(minHeight: 20)

        case .success(let message):
            Text(verbatim: message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KGColor.success)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 20)

        case .error(let message):
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KGColor.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: KGRadius.sm, style: .continuous)
                        .fill(KGColor.errorBg)
                )
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Rows

    private func chipState(for language: TargetLanguage) -> LanguageChip.ChipState {
        if state.isBusy {
            return state.activeLanguageID == language.id ? .working : .disabled
        }
        if state.replacedLanguageID == language.id { return .selected }
        return state.canTranslate ? .idle : .disabled
    }

    /// Tone actions only make sense once there's text, collapse to a hint when the field is empty.
    private var showsToneHint: Bool {
        state.canTranslate && !state.hasText && !state.isBusy && state.replacedLanguageID == nil
    }

    private var languageRow: some View {
        HStack(spacing: 7) {
            ForEach(state.languages) { language in
                Button { onSelect(language) } label: {
                    LanguageChip(
                        flag: language.flag,
                        name: language.name,
                        chipState: chipState(for: language)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!state.canTranslate)
                .accessibilityLabel(language.accessibilityLabel)
            }
        }
    }

    @ViewBuilder
    private var toneRow: some View {
        if showsToneHint {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(RewriteAction.all) { Text($0.glyph) }
                }
                .font(.system(size: 16))
                .opacity(0.45)
                Text("Tone actions appear once you've typed")
                    .font(.system(size: 11))
                    .foregroundStyle(KGColor.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        } else {
            HStack(spacing: 7) {
                ForEach(RewriteAction.all) { action in
                    Button { onRewrite(action) } label: {
                        ToneActionButton(
                            glyph: action.glyph,
                            label: LocalizedStringKey(action.name),
                            isDisabled: !state.canTranslate
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!state.canTranslate)
                    .accessibilityLabel(action.accessibilityLabel)
                }
            }
        }
    }

    private var utilityRow: some View {
        HStack(spacing: 7) {
            if state.showsNextKeyboard {
                NextKeyboardButton(configure: configureNextKeyboardButton)
                    .frame(width: 44, height: 44)
                    .background(KGColor.barButtonFill)
                    .clipShape(RoundedRectangle(cornerRadius: KGRadius.tone, style: .continuous))
            }

            if state.replacedLanguageID != nil {
                Button { onUndo() } label: {
                    HStack(spacing: 6) {
                        Text("↩︎").font(.system(size: 15))
                        Text("Undo, put my words back")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(KGColor.onInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(KGColor.ink)
                    .clipShape(RoundedRectangle(cornerRadius: KGRadius.tone, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Undo, put my words back"))
            } else {
                Button { onTranslateClipboard() } label: {
                    HStack(spacing: 6) {
                        Text("📋").font(.system(size: 15))
                        Text("Translate what they sent")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(KGColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(KGColor.barButtonFill)
                    .clipShape(RoundedRectangle(cornerRadius: KGRadius.tone, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!state.canTranslate)
                .opacity(state.canTranslate ? 1 : 0.5)
                .accessibilityLabel(Text("Translate a received message from the clipboard"))
            }
        }
    }

    // MARK: - Clipboard panel

    /// Read-only panel showing the translation of a received message (from the clipboard).
    private func clipboardPanel(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Received message").kgEyebrow(KGColor.accent)
                Spacer()
                Button { state.clipboardResult = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KGColor.ink2)
                        .frame(width: 24, height: 24)
                        .background(KGColor.fill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }
            ScrollView {
                ScriptText(text: text, size: 17, style: .body, color: KGColor.ink)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 24)     // a full line of clearance so the first line isn't cut off
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 4)
    }
}

/// A `UIButton`-backed globe that shows the system keyboard picker on long-press and
/// advances to the next keyboard on tap, the standard custom-keyboard behaviour that
/// SwiftUI alone cannot provide.
private struct NextKeyboardButton: UIViewRepresentable {
    let configure: (UIButton) -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.tintColor = UIColor(rgb: 0x6B6572)
        configure(button)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
