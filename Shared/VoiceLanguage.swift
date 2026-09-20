import Foundation

/// Shared helpers for the voice/audio translation features, the share extension (received voice
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

    // MARK: - Target ("you read") language

    struct TargetOption: Identifiable, Equatable {
        let id: String
        /// Shown in the picker/pill (native autonym).
        let name: String
        /// English name passed to the model as the translation target; `nil` = use device language.
        let englishName: String?
        /// BCP-47 voice code for read-aloud (TTS); `nil` = use the device language's voice.
        let voiceCode: String?
    }

    /// Target-language options. "Your language" (auto) keeps today's behaviour (device language).
    static let targetOptions: [TargetOption] = [
        .init(id: "auto", name: String(localized: "Your language"), englishName: nil, voiceCode: nil),
        .init(id: "en", name: "English",   englishName: "English",    voiceCode: "en-US"),
        .init(id: "it", name: "Italiano",  englishName: "Italian",    voiceCode: "it-IT"),
        .init(id: "fr", name: "Français",  englishName: "French",     voiceCode: "fr-FR"),
        .init(id: "es", name: "Español",   englishName: "Spanish",    voiceCode: "es-ES"),
        .init(id: "de", name: "Deutsch",   englishName: "German",     voiceCode: "de-DE"),
        .init(id: "pt", name: "Português", englishName: "Portuguese", voiceCode: "pt-BR"),
        .init(id: "ar", name: "العربية",   englishName: "Arabic",     voiceCode: "ar-SA"),
        .init(id: "zh", name: "中文",       englishName: "Chinese",    voiceCode: "zh-CN"),
        .init(id: "ja", name: "日本語",     englishName: "Japanese",   voiceCode: "ja-JP"),
        .init(id: "ko", name: "한국어",     englishName: "Korean",     voiceCode: "ko-KR"),
        .init(id: "ru", name: "Русский",   englishName: "Russian",    voiceCode: "ru-RU"),
        .init(id: "tr", name: "Türkçe",    englishName: "Turkish",    voiceCode: "tr-TR"),
    ]

    static func targetOption(for id: String) -> TargetOption {
        targetOptions.first { $0.id == id } ?? targetOptions[0]
    }

    /// English target-language name for the prompt, resolving "auto" to the device language.
    static func targetEnglishName(for id: String) -> String {
        targetOption(for: id).englishName ?? deviceLanguageEnglishName
    }

    /// BCP-47 voice code for read-aloud, resolving "auto" to the device's preferred language.
    static func targetVoiceCode(for id: String) -> String {
        targetOption(for: id).voiceCode ?? Locale.preferredLanguages.first ?? Locale.current.identifier
    }

    /// Gemini audio MIME for a file. The wrong MIME makes Gemini mis-decode the audio, so map
    /// carefully (m4a → audio/mp4, opus → audio/ogg).
    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "opus", "ogg", "oga": return "audio/ogg"
        case "mp3", "mpga", "mpeg": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aiff", "aif": return "audio/aiff"
        case "flac": return "audio/flac"
        default: return "audio/mp4"   // m4a / mp4, WhatsApp's default and what we record
        }
    }

    /// English name of the device language (e.g. "Italian"), used in the Gemini prompt.
    static var deviceLanguageEnglishName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
    }
}
