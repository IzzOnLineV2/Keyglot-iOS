# Keyglot — AI Translator

Keyglot is an iPhone translation toolkit powered by **your own AI provider key** — no backend,
nothing sensitive in this repo. It translates (and rewrites) wherever you need it:

- ⌨️ a **keyboard** that translates or rewrites the message you've already typed — in place, no copy/paste
- 📋 translate a **received message** you've copied
- 📤 a **share extension** that translates any shared **text** or **voice note** (WhatsApp included)
- 🎧 **Listen & translate** — press, speak, and it translates what it hears
- 📲 a **widget** that opens straight into listening

The goal is **natural communication**, not literal translation — output should read as if a native
speaker wrote it. Open source (**MIT**, see [`LICENSE`](LICENSE)); heading to TestFlight / the App Store.

## What it does

Both features work the same way — they replace the text iOS exposes around the cursor with the
AI result — and both flow through a single generic provider call.

### 🌍 Translate

Tap a language flag. The **source** language is auto-detected, so any language → any chosen
target works. You pick which languages appear (and in what order) in the app — up to
`Configuration.maxKeyboardLanguages` (default 7) from a catalog of **18**:

> English · Français · Modern Standard Arabic (العربية الفصحى) · Moroccan Darija — Arabic script
> (الدارجة) · Moroccan Darija — Latin/Arabizi · Italiano · Español · Português (Brasil) · Deutsch ·
> Nederlands · Русский · 中文 (Simplified) · 日本語 · 한국어 · Türkçe · हिन्दी · Polski · Ελληνικά

The five shown by default are English, French, MSA, and Moroccan Darija (Arabic + Latin).

### ✍️ Rewrite (same language)

Tap a tone action to improve or restyle the text **without translating it** — the language is
detected automatically and always preserved:

| Action | | What it does |
|---|---|---|
| ✨ | **Improve** | Fix grammar/spelling, make it more natural and fluent |
| 💼 | **Professional** | Formal tone for work, clients, business |
| 😊 | **Friendly** | Warmer, more conversational |
| ❤️ | **Flirty** | Light and playful — never explicit |

## AI provider

Both translation and rewriting go through a single `AIProvider` protocol, so the keyboard never
depends on a specific vendor. The method is intentionally generic — the caller supplies the full
system prompt — so the same call powers translation (`TargetLanguage.prompt`) and rewriting
(`RewriteAction.prompt`); the provider never knows which feature invoked it:

```swift
protocol AIProvider: Sendable {
    func generate(text: String, systemPrompt: String) async throws -> String
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
3. Either **tap a language flag** to translate, **or tap a tone action** (✨ 💼 😊 ❤️) to rewrite
   in the same language. For translation the **source** language is auto-detected, so any chosen
   target works.
4. The text in the field is replaced with the result. Press **Send**.

## Beyond the keyboard

The keyboard only sees the field you're typing in — these cover the rest:

### 📋 Translate a received message
Long-press a received message → **Copy**, switch to Keyglot, tap **📋** — it reads the clipboard,
translates into your language, and shows it in a read-only panel (never touching your reply).

### 📤 Share to Keyglot — text *or* voice note
From any app, share a **text selection / note / link**, or a **voice note** (WhatsApp → *Forward →
Share*), to Keyglot. Text is translated by your selected provider; **audio is transcribed +
translated by Google Gemini**, which understands dialects like Moroccan Darija that literal
speech-to-text mishears. A source-language picker lets you force the language if auto-detect is off.

### 🎧 Listen & translate + widget
**Listen & translate** (in the app, or from the home-screen **widget**) records immediately,
auto-stops on silence, and shows Gemini's translation of what it heard — a quick conversation
interpreter. The widget's mic button opens the app straight into listening via an **App Intent**
(no URL scheme). These audio features need a **Gemini** key.

## Project layout

```
AITranslateKeyboard/        Main app (SwiftUI) — onboarding, provider/key, language picker,
                            settings, About, and the "Listen & translate" screen (ListenView)
KeyboardExtension/          The keyboard: toolbar (languages + tones), translate/rewrite +
                            "translate from clipboard" (📋) flow
ShareExtension/             Share extension — translate shared text (selected provider) or a
                            voice note (Gemini): AudioShareModel / TextShareModel + views
Widget/                     WidgetKit widget — a mic button that opens the app into listening
                            (KeyglotListenWidget) via OpenListenIntent
Shared/                     Compiled into every target:
                              AIProvider         protocol + AIProviderType + factory + errors
                              ClaudeProvider / OpenAIProvider / GeminiProvider / OpenRouterProvider
                              GeminiAudioTranslator  audio → transcript + translation (Gemini)
                              Models             TargetLanguage catalog + per-language prompts
                              RewriteAction      tone actions (✨ 💼 😊 ❤️) + rewrite prompts
                              VoiceLanguage      source-language options + audio MIME helpers
                              OpenListenIntent   App Intent run by the widget
                              KeychainStore / CredentialStore   provider keys (shared Keychain)
                              AppGroupStorage    non-secret settings (provider, languages, …)
                              Configuration      endpoints, model ids, constants
project.yml                 XcodeGen spec — the source of truth for the Xcode project
AITranslateKeyboard.xcodeproj  Generated; open this in Xcode
```

Each target's own folder holds its code; `Shared/` is compiled into **all** of them (app, keyboard,
share, widget), and `PrivacyInfo.xcprivacy` + `*.entitlements` live in each target's folder.

## Build & run

Requirements: Xcode 16+ (built/verified on Xcode 26.5, Swift 6), an iPhone on iOS 18+.

1. Open `AITranslateKeyboard.xcodeproj`.
2. Select the **AITranslateKeyboard** target → *Signing & Capabilities* → set your **Team** with
   *Automatically manage signing*; Xcode applies it to the keyboard, share, and widget extensions
   too. (All targets declare the App Group `group.it.izzonline.keyglot`.)
3. Run on your iPhone (a third-party keyboard with network access only works on a real device).
4. On first launch the app shows a short **onboarding** screen. Pick your provider (default
   Claude) and paste an **API key for that provider** (e.g. `sk-ant-…` for Claude), then tap
   *Get Started*. You can change or remove keys, and switch provider, later in Settings.
5. On the phone: **Settings → General → Keyboard → Keyboards → Add New Keyboard… → Keyglot**.
6. Tap **Keyglot** in that list and enable **Allow Full Access** (required for network).

Until a key is configured, the keyboard's language and tone buttons stay **disabled** and the
toolbar prompts you to open the app and add one.

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
- `requestTimeout` — per-request network timeout (default 30s).
- `maxKeyboardLanguages` — how many languages the user can pin to the toolbar (default 7).
- `claudeModel` / `claudeMaxTokens` / `anthropicVersion` — Anthropic request settings.
- `openAIDefaultModel` / `openAIFallbackModel` / `openAIReasoningEffort` — OpenAI settings.
- `geminiModel` — Google Gemini model (e.g. `gemini-2.5-flash`).
- `openRouterModel` — any OpenRouter `vendor/model` id, plus optional attribution headers.
- `appGroupIdentifier` — if you change this, update both `.entitlements` files and `project.yml`.

## Notes & limitations

- **API key storage:** keys are stored in the **iOS Keychain** (`kSecClassGenericPassword`,
  `AfterFirstUnlockThisDeviceOnly`), never in `UserDefaults`. They sit in a **shared Keychain
  access group** (`$(AppIdentifierPrefix)it.izzonline.keyglot.shared`, declared in both
  targets' entitlements) so the keyboard extension can read them. The code omits
  `kSecAttrAccessGroup`, relying on the single-entry entitlement as the default group — so
  there's no hard-coded team-ID prefix to maintain. App Groups carry only the non-secret
  settings (selected provider, chosen language IDs + order).
- **Both App Groups and Keychain sharing need a real signing team.** With a free personal Apple
  ID these capabilities may not provision; a paid Apple Developer account is the reliable path.
  The keyboard can only read the key (and reach the network) when **Allow Full Access** is on.
- **Translates/rewrites the text iOS exposes around the cursor.** `documentContextBeforeInput`/
  `AfterInput` only return a window of text near the cursor and, in many host apps (WhatsApp
  included), stop at paragraph/newline boundaries. There is no full-text API for keyboard
  extensions (a privacy limit), so multi-paragraph messages process the current block, not
  necessarily the whole field. Works fully for single-block messages.
- On any API/network failure the banner shows the reason (e.g. *"Invalid API key"*, *"No
  credit — add billing"*) and your original text is left untouched.

## License

Keyglot is released under the [MIT License](LICENSE) — you're free to use, modify, and
distribute the code. The **“Keyglot” name, icon, and branding are not covered by the license**
and remain the property of IzzOnLine di Stefania Izzo; please don't publish a copy under the
same identity.
