import Foundation

/// A same-language rewrite action: it improves or restyles the text the user already typed
/// without translating it. This is the second half of Keyglot — alongside translation — that
/// turns it into a universal AI writing assistant.
///
/// Each action is just a glyph + a system prompt. The source language is auto-detected and
/// always preserved; only the tone/quality changes.
struct RewriteAction: Identifiable, Codable, Equatable, Sendable {
    /// Stable key (do not change once shipped).
    let id: String
    /// Emoji shown on the toolbar button.
    let glyph: String
    /// Short name (settings, accessibility).
    let name: String
    /// Per-action instruction appended to the global rewrite rules.
    let instruction: String

    /// System instruction sent to the model. Provider-agnostic.
    var prompt: String { Self.globalRules + "\n\n" + instruction }

    var accessibilityLabel: String {
        switch id {
        case "improve": return String(localized: "Improve the text")
        case "professional": return String(localized: "Rewrite in a professional tone")
        case "friendly": return String(localized: "Rewrite in a friendly tone")
        case "flirty": return String(localized: "Rewrite in a flirty tone")
        default: return name
        }
    }

    // MARK: - Catalog

    /// The four fixed rewrite actions, in toolbar order: ✨ 💼 😊 ❤️.
    /// Kept intentionally small — a focused first version, not dozens of tones.
    static let all: [RewriteAction] = [
        RewriteAction(id: "improve", glyph: "✨", name: "Improve", instruction: """
            Improve the message:
            - Correct grammar, spelling and punctuation.
            - Make the text more natural and fluent.
            - Preserve the original meaning.
            """),
        RewriteAction(id: "professional", glyph: "💼", name: "Professional", instruction: """
            Rewrite the message in a more formal and professional tone,
            suitable for work, HR, clients and business communications.
            Preserve the original meaning.
            """),
        RewriteAction(id: "friendly", glyph: "😊", name: "Friendly", instruction: """
            Rewrite the message in a warmer, more friendly and conversational tone.
            Preserve the original meaning.
            """),
        RewriteAction(id: "flirty", glyph: "❤️", name: "Flirty", instruction: """
            Rewrite the message in a light, playful and natural flirty tone.
            Never explicit. Never exaggerated.
            Preserve the original meaning.
            """),
    ]

    // MARK: - Prompt

    /// Rules that apply to every rewrite. The defining constraint: never translate — the output
    /// must stay in the same language the user wrote in.
    private static let globalRules = """
    You are an expert writing assistant powering a personal messaging keyboard.
    Rewrite the user's message IN THE SAME LANGUAGE it is written in — detect the language
    automatically and never translate it to another language.
    Follow these rules strictly:
    - Keep the same language as the input.
    - Preserve the meaning, names, emojis, URLs, phone numbers and any specific details.
    - Keep it natural and appropriate for everyday personal chat.
    - Do NOT add explanations, notes, quotes, labels or introductions.
    - Return ONLY the final rewritten message and nothing else.
    """
}
