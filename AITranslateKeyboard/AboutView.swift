import SwiftUI

struct AboutView: View {
    @StateObject private var store = StoreManager()
    private let provider = AppGroupStorage.shared.selectedProvider
    private let languages = AppGroupStorage.shared.selectedLanguages

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                KGCard {
                    VStack(alignment: .leading, spacing: 8) {
                        LogoMark(size: 48)
                        Text("Keyglot").font(KGFont.title).foregroundStyle(KGColor.ink)
                        Text("AI Message Translator").font(KGFont.row).foregroundStyle(KGColor.ink2)
                        Text("Keyglot translates or rewrites the message you've already typed, in place, without copy/paste. Tap a language for a natural translation (source language auto-detected), or tap a tone to improve or restyle your text in the same language.")
                            .font(KGFont.body).foregroundStyle(KGColor.ink2)
                    }
                }

                // Support (in-app IAP; PayPal stays external, per App Store rules)
                section("Support Keyglot") {
                    if store.isSupporter {
                        Label("Support Keyglot", systemImage: "checkmark.seal.fill")
                            .font(KGFont.row).foregroundStyle(KGColor.success)
                    } else {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            HStack {
                                Text("Support Keyglot").foregroundStyle(KGColor.ink)
                                Spacer()
                                Text(store.product?.displayPrice ?? "€1,99").foregroundStyle(KGColor.ink2)
                            }
                            .font(KGFont.row)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(store.product == nil)
                    }
                }

                section("How it works") {
                    VStack(alignment: .leading, spacing: 10) {
                        bullet("Type your message in any app with your normal keyboard.")
                        bullet("Tap 🌐 to switch to the Keyglot keyboard.")
                        bullet("Tap a language to translate, or a tone (✨ 💼 😊 ❤️) to rewrite, the text is replaced in place.")
                        bullet("Press Send.")
                        bullet("Choose which languages appear in Settings → Keyboard → Languages.")
                    }
                }

                section("Fix and improve your writing") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Writing in a language that isn't your own? Fix and polish your message before you send it, in the same language, no translation. Or restyle the tone.")
                            .font(KGFont.body).foregroundStyle(KGColor.ink2)
                        VStack(alignment: .leading, spacing: 10) {
                            tone("✨", "Improve", "Fix grammar and spelling, make it read naturally.")
                            tone("💼", "Professional", "A formal tone for work, clients and business.")
                            tone("😊", "Friendly", "Warmer and more conversational.")
                            tone("❤️", "Flirty", "Light and playful, never explicit.")
                        }
                    }
                }

                section("More ways to translate") {
                    VStack(alignment: .leading, spacing: 10) {
                        bullet("🎧 Listen & translate, press, speak, and get a translation of what you hear (also from the widget).")
                        bullet("📋 Translate a message you've copied, tap 📋 on the keyboard.")
                        bullet("📤 Share any text or voice note to Keyglot to translate it.")
                        Text("Audio (voice notes and live listening) uses Google Gemini, add a Gemini API key in Settings to use it.")
                            .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                    }
                }

                section("Keyboard languages") {
                    VStack(spacing: 8) {
                        ForEach(languages) { language in
                            HStack {
                                Text(language.name).font(KGFont.row).foregroundStyle(KGColor.ink)
                                Spacer()
                                Text(language.flag)
                            }
                        }
                    }
                }

                section("Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        detail("Version", appVersion)
                        detail("Provider", provider.displayName)
                        detail("Model", provider.modelName)
                        Text("Your API key is stored in the iOS Keychain on this device. Messages are sent only to the selected AI provider for translation or rewriting.")
                            .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                    }
                }

                section("Developer") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Developed by Stefania Izzo").font(KGFont.row).foregroundStyle(KGColor.ink)
                        Text("IzzOnLine di Stefania Izzo").font(KGFont.caption).foregroundStyle(KGColor.ink2)
                        Link(destination: URL(string: "https://izzonline.it")!) {
                            Label("izzonline.it", systemImage: "globe").font(KGFont.row).foregroundStyle(KGColor.accent)
                        }
                    }
                }
            }
            .padding()
        }
        .background(KGColor.canvas)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).kgEyebrow()
            KGCard { content() }
        }
    }

    private func detail(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).font(KGFont.row).foregroundStyle(KGColor.ink)
            Spacer()
            Text(value).font(KGFont.row).foregroundStyle(KGColor.ink2)
        }
    }

    private func tone(_ glyph: String, _ name: LocalizedStringKey, _ desc: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(glyph).font(.system(size: 18)).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(KGFont.row).foregroundStyle(KGColor.ink)
                Text(desc).font(KGFont.caption).foregroundStyle(KGColor.ink2)
            }
        }
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").font(KGFont.body).foregroundStyle(KGColor.accent)
            Text(text).font(KGFont.body).foregroundStyle(KGColor.ink2)
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
