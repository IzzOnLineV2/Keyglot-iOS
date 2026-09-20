import SwiftUI
import UIKit

/// "Listen & translate": opens (from Settings or the widget deep link), starts recording
/// immediately, auto-stops on silence, and shows Gemini's translation of what it heard.
struct ListenView: View {
    @StateObject private var vm = ListenViewModel()
    @State private var copied = false

    // Fixed dark surface for the "listening" state (design 07), independent of light/dark mode.
    private let listenBg = Color(hex: 0x0F0E13)
    private let listenInk = Color(hex: 0xF7F4FA)
    private let listenInk2 = Color(hex: 0xA79FB4)

    var body: some View {
        ZStack {
            (isRecording ? listenBg : KGColor.canvas).ignoresSafeArea()
            content.padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if vm.phase == .idle { vm.start() } }
        .onDisappear { vm.cancel() }
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
            sourcePill
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
            sourcePill
            ScrollView {
                TranslationResultCard(translation: translation, original: transcript,
                                      originalLabel: "What they said")
            }
            HStack(spacing: 9) {
                Button { copy(translation) } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.kgSecondary)
                Button { vm.start() } label: {
                    Label("Listen again", systemImage: "mic.fill")
                }
                .buttonStyle(.kgPrimary)
            }
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

    // MARK: - Source language

    private var sourcePill: some View {
        Menu {
            ForEach(VoiceLanguage.options) { lang in
                Button {
                    vm.setLanguage(lang.id)
                } label: {
                    if lang.id == vm.selectedID {
                        Label(lang.name, systemImage: "checkmark")
                    } else {
                        Text(lang.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe").foregroundStyle(KGColor.accent)
                Text("Audio language").foregroundStyle(KGColor.ink)
                Spacer()
                Text(VoiceLanguage.option(for: vm.selectedID).name).foregroundStyle(KGColor.ink2)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(KGColor.ink3)
            }
            .font(KGFont.row)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
    NavigationStack { ListenView() }
}
