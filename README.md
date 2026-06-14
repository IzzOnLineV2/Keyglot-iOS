# Keyglot Keyboard

A personal iPhone keyboard extension that translates the message you've already typed —
**in place, without copy/paste** — into English, French, Modern Standard Arabic, or
Moroccan Darija (Arabic or Latin/Arabizi script).

The goal is **natural communication**, not literal translation — output should read as if a
native speaker wrote it. Not for the App Store. No backend. The AI provider is called
directly from the device.

## AI provider

Translation goes through a single `AIProvider` protocol, so the keyboard never depends on a
specific vendor:

```swift
protocol AIProvider {
    func translate(text: String, targetLanguage: TargetLanguage) async throws -> String
}
```

Four providers are supported, each a small raw-HTTP `URLSession` client:

| Provider | Type / API | Default model | Key from |
|---|---|---|---|
| **Claude Sonnet** (default) | `ClaudeProvider` — Anthropic Messages API | `claude-sonnet-4-6` | console.anthropic.com |
| **OpenAI GPT** | `OpenAIProvider` — Responses API (`gpt-5-mini`→`gpt-5-nano` fallback) | `gpt-5-mini` | platform.openai.com |
| **Google Gemini** | `GeminiProvider` — Generative Language API (`generateContent`) | `gemini-2.0-flash` | aistudio.google.com |
| **OpenRouter** | `OpenRouterProvider` — OpenAI-compatible gateway (`chat/completions`) | `openai/gpt-4o-mini` | openrouter.ai |

The provider is chosen in onboarding and in Settings (default Claude Sonnet); **each provider
stores its own API key** in the Keychain. Default models live in `Configuration.swift` and are
easy to change. Adding a fifth provider = one new `AIProvider` conformer + one `AIProviderType`
case.

## How it works

A custom keyboard *replaces* the system keyboard, so the flow is:

1. Type your message in any app (WhatsApp, Telegram, iMessage…) with your normal keyboard.
2. Tap 🌐 to switch to the **Keyglot** keyboard.
3. Tap a language. You choose which languages appear (and in what order) in the app — up to
   `Configuration.maxKeyboardLanguages` (default 7) from a catalog of ~18. The **source**
   language is auto-detected, so any language → any chosen target works.
4. The text in the field is replaced with the translation. Press **Send**.

## Project layout

```
AITranslateKeyboard/        Main app (SwiftUI) — provider/key/settings
KeyboardExtension/          The keyboard: toolbar UI + translation flow
Shared/                     Compiled into both targets:
                              AIProvider        protocol + AIProviderType + factory + errors
                              ClaudeProvider    Anthropic Messages API (default)
                              OpenAIProvider    OpenAI Responses API
                              GeminiProvider    Google Generative Language API
                              OpenRouterProvider OpenRouter (OpenAI-compatible)
                              Models            TargetLanguage catalog + per-language prompts
                              KeychainStore     low-level shared-Keychain wrapper
                              CredentialStore   provider API keys (Keychain-backed)
                              AppGroupStorage   non-secret settings (provider, language)
                              Configuration     endpoints, model ids, constants
project.yml                 XcodeGen spec — the source of truth for the Xcode project
AITranslateKeyboard.xcodeproj  Generated; open this in Xcode
```

The `Shared/` files are members of **both** targets so the app and the keyboard share one
implementation.

## Build & run

Requirements: Xcode 16+ (built/verified on Xcode 26.5, Swift 6), an iPhone on iOS 18+.

1. Open `AITranslateKeyboard.xcodeproj`.
2. Select the **AITranslateKeyboard** target → *Signing & Capabilities* → set your **Team**.
   Do the same for the **AITranslateKeyboardExtension** target.
   (Both targets already declare the App Group `group.com.smartapibox.keyglot`.)
3. Run on your iPhone (a third-party keyboard with network access only works on a real device).
4. On first launch the app shows a short **onboarding** screen that requires a Claude API key
   (`sk-ant-…`) before anything else — paste it and tap *Get Started*. You can change or remove
   keys, and switch provider, later in Settings.
5. On the phone: **Settings → General → Keyboard → Keyboards → Add New Keyboard… → Keyglot**.
6. Tap **Keyglot** in that list and enable **Allow Full Access** (required for network).

Until a key is configured, the keyboard's language buttons stay **disabled** and the toolbar
prompts you to open the app and add one.

### Regenerating the Xcode project

The `.xcodeproj` is generated from `project.yml`. After adding/removing files or targets:

```sh
brew install xcodegen   # once
xcodegen generate
```

Source files live in folders (`Shared/`, `KeyboardExtension/`, `AITranslateKeyboard/`), so new
files are picked up automatically on regenerate. You don't need XcodeGen just to build — the
generated `.xcodeproj` is self-contained.

## Configuration

Edit `Shared/Configuration.swift`:

- `defaultProvider` — `.claude`.
- `claudeModel` / `claudeMaxTokens` / `anthropicVersion` — Anthropic request settings.
- `openAIDefaultModel` / `openAIFallbackModel` / `openAIReasoningEffort` — OpenAI settings.
- `appGroupIdentifier` — if you change this, update both `.entitlements` files and `project.yml`.

## Notes & limitations (MVP)

- **API key storage:** keys are stored in the **iOS Keychain** (`kSecClassGenericPassword`,
  `AfterFirstUnlockThisDeviceOnly`), never in `UserDefaults`. They sit in a **shared Keychain
  access group** (`$(AppIdentifierPrefix)com.smartapibox.keyglot.shared`, declared in both
  targets' entitlements) so the keyboard extension can read them. The code omits
  `kSecAttrAccessGroup`, relying on the single-entry entitlement as the default group — so
  there's no hard-coded team-ID prefix to maintain. App Groups carry only the non-secret
  settings (selected provider, default language).
- **Both App Groups and Keychain sharing need a real signing team.** With a free personal Apple
  ID these capabilities may not provision; a paid Apple Developer account is the reliable path.
  The keyboard can only read the key (and reach the network) when **Allow Full Access** is on.
- **Translates the text iOS exposes around the cursor.** `documentContextBeforeInput`/`AfterInput`
  only return a window of text near the cursor and, in many host apps (WhatsApp included), stop at
  paragraph/newline boundaries. There is no full-text API for keyboard extensions (a privacy
  limit), so multi-paragraph messages translate the current block, not necessarily the whole
  field. Works fully for single-block messages.
- On any API/network failure the banner shows the reason (e.g. *"Invalid API key"*, *"No
  credits — add billing"*) and your original text is left untouched.
