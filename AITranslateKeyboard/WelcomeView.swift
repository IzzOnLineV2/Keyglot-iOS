import SwiftUI

/// Consumer welcome shown once on first launch: what Keyglot does and where it shows up. No API
/// keys, no jargon, the point is you never open the app to translate.
struct WelcomeView: View {
    let onDone: () -> Void
    /// Whether finishing offers the KeyGlot Pro screen. True only for the real first-run onboarding;
    /// false when replaying the intro from Settings ("Show welcome again"), where nudging to pay is
    /// unwanted, especially for existing Pro users.
    var promptsPaywall: Bool = true
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var page = 0
    @State private var showPro = false

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            VStack(spacing: 20) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    placesPage.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots

                Button(page == 0 ? "Show me how" : "Set up my keyboard") {
                    if page == 0 { withAnimation { page = 1 } } else { advance() }
                }
                .buttonStyle(.kgPrimary)
            }
            .padding(24)
        }
        .fullScreenCover(isPresented: $showPro) {
            ProPaywallView(onClose: { showPro = false; onDone() })
                .environmentObject(subscription)
        }
    }

    /// After the two intro pages: new KeyGlot users see the Pro screen (design 05, screen 3); if
    /// already subscribed or in Custom mode, go straight home.
    private func advance() {
        if promptsPaywall && AppGroupStorage.shared.aiMode == .keyglot && !subscription.isSubscribed {
            showPro = true
        } else {
            onDone()
        }
    }

    // MARK: Page 1, welcome

    private var welcomePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                chatDemo
                VStack(alignment: .leading, spacing: 12) {
                    Text("Understand every message. Answer in your words.")
                        .font(KGFont.serif(38, style: .largeTitle))
                        .foregroundStyle(KGColor.ink)
                    Text("A friend writes in a language you don't speak, Keyglot translates it, and turns your reply into their language, right where you're already typing.")
                        .font(KGFont.body).foregroundStyle(KGColor.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
    }

    private var chatDemo: some View {
        VStack(spacing: 14) {
            // Incoming (Darija)
            HStack {
                ScriptText(text: "واش نتي جاية غدا؟", size: 16, color: KGColor.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(KGColor.surface, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 20, bottomLeading: 6, bottomTrailing: 20, topTrailing: 20)))
                    .kgShadow(.card)
                Spacer(minLength: 40)
            }
            // Seam with "Keyglot" eyebrow
            HStack(spacing: 8) {
                LinearGradient(colors: [Color(hex: 0x22C3D6).opacity(0), Color(hex: 0x7A5BF0)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 2)
                Text("Keyglot").kgEyebrow(KGColor.accent)
                LinearGradient(colors: [Color(hex: 0x7A5BF0), Color(hex: 0xF0609B).opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 2)
            }
            // Reply (yours)
            HStack {
                Spacer(minLength: 40)
                Text("Yes! I'll be there at seven 😊")
                    .font(KGFont.body).foregroundStyle(KGColor.onInk)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(KGColor.ink, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 20, bottomLeading: 20, bottomTrailing: 6, topTrailing: 20)))
            }
        }
    }

    // MARK: Page 2, where it works

    private var placesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Three places Keyglot shows up")
                        .font(KGFont.serif(34, style: .largeTitle))
                        .foregroundStyle(KGColor.ink)
                    Text("You'll never open this app to translate something. That's the point.")
                        .font(KGFont.body).foregroundStyle(KGColor.ink2)
                }

                feature("⌨️", Color(hex: 0xEDE9FE), "Write it, then switch it",
                        "Type in your language, tap a flag, and your message becomes a natural translation, right where you type: WhatsApp, Messages, email.")
                feature("🎧", Color(hex: 0xDFF4F7), "Got a voice note you can't follow?",
                        "Share it to Keyglot and read what it says, dialects included.")
                feature("🎙️", Color(hex: 0xFDE9F1), "Talking face to face",
                        "Open “Listen & translate”, and hear what they said in your language. Add the widget for one-tap access.")
            }
            .padding(.top, 8)
        }
    }

    private func feature(_ glyph: String, _ tint: Color, _ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        KGCard {
            HStack(alignment: .top, spacing: 12) {
                Text(glyph).font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(tint, in: RoundedRectangle(cornerRadius: KGRadius.tone, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16.5, weight: .semibold)).foregroundStyle(KGColor.ink)
                    Text(body).font(KGFont.caption).foregroundStyle(KGColor.ink2)
                }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i == page ? KGColor.ink : KGColor.ink3.opacity(0.4))
                    .frame(width: i == page ? 18 : 5, height: 5)
            }
        }
    }
}

#Preview {
    WelcomeView(onDone: {}).environmentObject(SubscriptionManager())
}
