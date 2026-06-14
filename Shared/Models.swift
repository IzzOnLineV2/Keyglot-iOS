import Foundation

/// A target language the keyboard can translate into. No longer a fixed enum: it's a catalog
/// entry, so the set shown on the keyboard is user-configurable.
///
/// The source language is always auto-detected by the model — these only describe the target.
struct TargetLanguage: Identifiable, Codable, Equatable, Sendable {
    /// Stable key persisted in settings (do not change once shipped).
    let id: String
    /// Display name (settings, About, accessibility, generic prompt).
    let name: String
    /// Glyph shown on the toolbar button.
    let flag: String
    /// Per-language instruction appended to the global rules.
    let instruction: String

    /// System instruction sent to the model. Provider-agnostic.
    var prompt: String { Self.globalRules + "\n\n" + instruction }

    var accessibilityLabel: String { String(localized: "Translate to \(name)") }
    /// Kept as an alias so existing call sites compile unchanged.
    var title: String { name }

    // MARK: - Catalog

    static func byID(_ id: String) -> TargetLanguage? { catalog.first { $0.id == id } }

    /// Languages shown by default (matches the original five).
    static let defaultIDs = ["en", "fr", "ar", "darija_ar", "darija_latin"]

    private static func generic(_ name: String) -> String {
        "Translate the message into natural, conversational \(name)."
    }

    /// The full set of languages the user can choose from. Add a row here to offer a new one.
    static let catalog: [TargetLanguage] = [
        TargetLanguage(id: "en", name: "English", flag: "🇬🇧", instruction: generic("English")),
        TargetLanguage(id: "fr", name: "Français", flag: "🇫🇷", instruction: generic("French")),
        TargetLanguage(id: "ar", name: "العربية الفصحى", flag: "🇸🇦",
                       instruction: "Translate the message into Modern Standard Arabic. Use Arabic script."),
        TargetLanguage(id: "darija_ar", name: "الدارجة", flag: "🇲🇦", instruction: """
            Translate the message into natural Moroccan Darija (the spoken dialect),
            written in Arabic script.
            Do NOT use Modern Standard Arabic.
            Write exactly as a Moroccan would write in a casual chat conversation.
            """),
        TargetLanguage(id: "darija_latin", name: "Darija (Latin)", flag: "🇲🇦", instruction: """
            Translate the message into natural Moroccan Darija (the spoken dialect),
            written with Latin characters and the common Moroccan chat notation
            (Arabizi), for example: 3 = ع, 7 = ح, 9 = ق, 5 = خ.
            Use the style commonly used in WhatsApp conversations.
            Do NOT use Arabic script.
            """),
        TargetLanguage(id: "it", name: "Italiano", flag: "🇮🇹", instruction: generic("Italian")),
        TargetLanguage(id: "es", name: "Español", flag: "🇪🇸", instruction: generic("Spanish")),
        TargetLanguage(id: "pt", name: "Português (Brasil)", flag: "🇧🇷",
                       instruction: "Translate the message into natural, conversational Brazilian Portuguese."),
        TargetLanguage(id: "de", name: "Deutsch", flag: "🇩🇪", instruction: generic("German")),
        TargetLanguage(id: "nl", name: "Nederlands", flag: "🇳🇱", instruction: generic("Dutch")),
        TargetLanguage(id: "ru", name: "Русский", flag: "🇷🇺", instruction: generic("Russian")),
        TargetLanguage(id: "zh", name: "中文", flag: "🇨🇳",
                       instruction: "Translate the message into Simplified Chinese (Mandarin). Use Chinese characters (Hanzi)."),
        TargetLanguage(id: "ja", name: "日本語", flag: "🇯🇵", instruction: generic("Japanese")),
        TargetLanguage(id: "ko", name: "한국어", flag: "🇰🇷", instruction: generic("Korean")),
        TargetLanguage(id: "tr", name: "Türkçe", flag: "🇹🇷", instruction: generic("Turkish")),
        TargetLanguage(id: "hi", name: "हिन्दी", flag: "🇮🇳", instruction: generic("Hindi")),
        TargetLanguage(id: "pl", name: "Polski", flag: "🇵🇱", instruction: generic("Polish")),
        TargetLanguage(id: "el", name: "Ελληνικά", flag: "🇬🇷", instruction: generic("Greek")),
    ]

    // MARK: - Prompt

    /// Rules that apply to every translation. The goal is natural communication, not a literal
    /// word-for-word rendering. The source language is auto-detected.
    private static let globalRules = """
    You are an expert translator powering a personal messaging keyboard.
    Translate the user's message so it reads as if it had been written natively by a fluent
    speaker — natural communication, not a literal word-for-word translation.
    Follow these rules strictly:
    - Convey the meaning, tone and intent; phrase it the way a native speaker actually would.
    - Keep it conversational and culturally appropriate for everyday personal chat.
    - Preserve emojis, names, URLs, phone numbers and punctuation exactly.
    - Do NOT add explanations, notes, quotes, labels or introductions.
    - Return ONLY the final translated message and nothing else.
    """
}
