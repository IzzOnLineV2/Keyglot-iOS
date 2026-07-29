import Foundation

/// Shared helpers for the voice/audio translation features — the share extension (received voice
/// notes) and the in-app "Listen & translate" screen. Keeps the source-language options and the
/// audio MIME/target-language logic in one place.
enum VoiceLanguage {

    struct Option: Identifiable, Equatable {
        let id: String
        /// Shown in the picker (native autonym).
        let name: String
        /// English hint passed to Gemini as the likely source language; `nil` = auto-detect.
        let hint: String?
    }

    /// Source-language options for the picker. Auto-detect works for most; the Darija hint helps
    /// when a dialect is misheard.
    static let options: [Option] = [
        .init(id: "auto", name: String(localized: "Automatic (detect)"), hint: nil),
        .init(id: "ar",   name: "العربية · Darija", hint: "Moroccan Darija (Arabic)"),
        .init(id: "fr",   name: "Français", hint: "French"),
        .init(id: "en",   name: "English", hint: "English"),
        .init(id: "es",   name: "Español", hint: "Spanish"),
        .init(id: "it",   name: "Italiano", hint: "Italian"),
        .init(id: "de",   name: "Deutsch", hint: "German"),
        .init(id: "pt",   name: "Português", hint: "Portuguese"),
        .init(id: "tr",   name: "Türkçe", hint: "Turkish"),
        .init(id: "ru",   name: "Русский", hint: "Russian"),
        .init(id: "zh",   name: "中文", hint: "Chinese"),
    ]

    static func option(for id: String) -> Option {
        options.first { $0.id == id } ?? options[0]
    }

    static func hint(for id: String) -> String? { option(for: id).hint }

    /// Gemini audio MIME for a file. The wrong MIME makes Gemini mis-decode the audio, so map
    /// carefully (m4a → audio/mp4, opus → audio/ogg).
    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "opus", "ogg", "oga": return "audio/ogg"
        case "mp3", "mpga", "mpeg": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "flac": return "audio/flac"
        default: return "audio/mp4"   // m4a / mp4 — WhatsApp's default and what we record
        }
    }

    /// English name of the device language (e.g. "Italian"), used in the Gemini prompt.
    static var deviceLanguageEnglishName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
    }
}
