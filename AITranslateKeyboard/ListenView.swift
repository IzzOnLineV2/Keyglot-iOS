import SwiftUI
import UIKit

/// "Listen & translate": opens (from Settings or the widget deep link), starts recording
/// immediately, auto-stops on silence, and shows Gemini's translation of what it heard.
struct ListenView: View {
    @EnvironmentObject private var subscription: SubscriptionManager
    @StateObject private var vm = ListenViewModel()
    @State private var copied = false
    @State private var showPro = false

    // Fixed dark surface for the "listening" state (design 07), independent of light/dark mode.
    private let listenBg = Color(hex: 0x0F0E13)
    private let listenInk = Color(hex: 0xF7F4FA)
    private let listenInk2 = Color(hex: 0xA79FB4)

    /// The audio features need either KeyGlot Pro (managed) or, in Custom mode, a Gemini key.
    private var needsSetup: Bool {
        switch AppGroupStorage.shared.aiMode {
        case .keyglot: return !subscription.isSubscribed
        case .custom:  return !CredentialStore.shared.hasAPIKey(for: .gemini)
        }
    }

    private var isCustom: Bool { AppGroupStorage.shared.aiMode == .custom }

    var body: some View {
        Group {
            if needsSetup { setupScreen } else { listenScreen }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPro) {
            ProPaywallView(onClose: { showPro = false }).environmentObject(subscription)
        }
        .onAppear { if !needsSetup && vm.phase == .idle { vm.start() } }
        .onChange(of: subscription.isSubscribed) { _, subscribed in
            if subscribed && vm.phase == .idle { vm.start() }
        }
        .onDisappear { vm.cancel() }
    }

    // MARK: - Setup required (nice screen instead of an error)

    private var setupScreen: some View {
        SetupRequiredView(
            icon: isCustom ? "key.fill" : "sparkles",
            title: "Set up Keyglot to start",
            message: isCustom
                ? "Voice needs a Google Gemini key. Add one in Advanced → Voice notes key."
                : "Voice is included with KeyGlot Pro. Subscribe to use it, or switch to Custom in Advanced with your own Gemini key.",
            actionTitle: isCustom ? nil : "Get KeyGlot Pro",
            action: isCustom ? nil : { showPro = true }
        )
    }

    private var listenScreen: some View {
        ZStack {
            (isRecording ? listenBg : KGColor.canvas).ignoresSafeArea()
            content.padding()
        }
    }

    private var isRecording: Bool { vm.phase == .recording }

    // MARK: - Content per state

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle:       idleView
        case .recording:  recordingView
        case .processing: processingView
        case .result(let transcript, let translation): resultView(transcript, translation)
        case .noSpeech:   noSpeechView
        case .failed(let message): failedView(message)
        }
    }

    // MARK: Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Listen & translate").font(KGFont.serif(34, style: .largeTitle)).foregroundStyle(KGColor.ink)
                Text("Hold the phone between you. Press, let them speak, and read what they said.")
                    .font(KGFont.body).foregroundStyle(KGColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            languagePills
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                MicButton(state: .idle) { vm.start() }
                Text("Press to listen").font(KGFont.body).fontWeight(.semibold).foregroundStyle(KGColor.ink)
                Text("It stops on its own when the room goes quiet.")
                    .font(KGFont.caption).foregroundStyle(KGColor.ink2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    // MARK: Recording (dark surface + live timer)

    private var recordingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Listening…").font(KGFont.serif(34, style: .largeTitle)).foregroundStyle(listenInk)
            Text("Go ahead, I'll stop when they do.").font(KGFont.body).foregroundStyle(listenInk2)
            Spacer(minLength: 0)
            VStack(spacing: 24) {
                MicButton(state: .listening, level: vm.level) { vm.stop() }
                Text(timeString(vm.elapsed)).font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(listenInk)
                Button("Stop now") { vm.stop() }
                    .font(KGFont.row.weight(.semibold)).foregroundStyle(listenInk)
                    .padding(.horizontal, 26).padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous)
                            .strokeBorder(Color(hex: 0x3A3549), lineWidth: 1.5)
                    )
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    // MARK: Processing

    private var processingView: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                MicButton(state: .processing)
                Text("Working out what that was…").font(KGFont.body).fontWeight(.semibold).foregroundStyle(KGColor.ink)
                Text("Usually two or three seconds").font(KGFont.caption).foregroundStyle(KGColor.ink3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Result

    private func resultView(_ transcript: String, _ translation: String) -> some View {
        VStack(spacing: 16) {
            languagePills
            ScrollView {
                TranslationResultCard(translation: translation, original: transcript,
                                      originalLabel: "What they said")
            }
            HStack(spacing: 9) {
                Button { vm.toggleSpeak(translation) } label: {
                    Label(vm.isSpeaking ? "Stop" : "Read aloud",
                          systemImage: vm.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.kgSecondary)
                Button { copy(translation) } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.kgSecondary)
            }
            Button { vm.start() } label: {
                Label("Listen again", systemImage: "mic.fill")
            }
            .buttonStyle(.kgPrimary)
        }
    }

    // MARK: No speech (gentle)

    private var noSpeechView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Text("🤫").font(.system(size: 34))
            Text("It was too quiet to catch").font(KGFont.body).fontWeight(.semibold).foregroundStyle(KGColor.ink)
            Text("Try again a bit closer, or hold the phone toward them.")
                .font(KGFont.caption).foregroundStyle(KGColor.ink2).multilineTextAlignment(.center)
            Button("Try again") { vm.start() }.buttonStyle(.kgPrimary).fixedSize().padding(.top, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Failed (permissions / network)

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(KGColor.attention)
            Text(message).font(KGFont.body).foregroundStyle(KGColor.ink2).multilineTextAlignment(.center)
            Button("Try again") { vm.start() }.buttonStyle(.kgSecondary).fixedSize()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Language pills (they speak · you read)

    private var languagePills: some View {
        HStack(spacing: 9) {
            pill(caption: "they speak", value: VoiceLanguage.option(for: vm.selectedID).name) {
                ForEach(VoiceLanguage.options) { lang in
                    Button { vm.setLanguage(lang.id) } label: {
                        if lang.id == vm.selectedID { Label(lang.name, systemImage: "checkmark") } else { Text(lang.name) }
                    }
                }
            }
            pill(caption: "you read", value: VoiceLanguage.targetOption(for: vm.targetID).name) {
                ForEach(VoiceLanguage.targetOptions) { target in
                    Button { vm.setTarget(target.id) } label: {
                        if target.id == vm.targetID { Label(target.name, systemImage: "checkmark") } else { Text(target.name) }
                    }
                }
            }
        }
    }

    private func pill<Content: View>(caption: LocalizedStringKey, value: String,
                                     @ViewBuilder menu: () -> Content) -> some View {
        Menu { menu() } label: {
            HStack(spacing: 7) {
                Text(caption).font(.system(size: 11)).foregroundStyle(KGColor.ink3)
                Text(value).font(KGFont.row.weight(.semibold)).foregroundStyle(KGColor.ink).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(KGColor.surface, in: RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous)
                    .strokeBorder(KGColor.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
    }
}

#Preview {
    NavigationStack { ListenView() }.environmentObject(SubscriptionManager())
}
