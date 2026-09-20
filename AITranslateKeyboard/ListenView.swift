import SwiftUI

/// "Listen & translate": opens (from Settings or the widget deep link), starts recording
/// immediately, auto-stops on silence, and shows Gemini's translation of what it heard.
struct ListenView: View {
    @StateObject private var vm = ListenViewModel()

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            VStack(spacing: 20) {
                sourcePill
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle(Text("Listen & translate"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if vm.phase == .idle { vm.start() } }
        .onDisappear { vm.cancel() }
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle:
            VStack(spacing: 14) {
                MicButton(state: .idle) { vm.start() }
                Text("Press to listen").font(KGFont.body).fontWeight(.semibold).foregroundStyle(KGColor.ink)
                Text("It stops on its own when the room goes quiet.")
                    .font(KGFont.caption).foregroundStyle(KGColor.ink2).multilineTextAlignment(.center)
            }

        case .recording:
            VStack(spacing: 18) {
                MicButton(state: .listening, level: vm.level) { vm.stop() }
                Button("Stop now") { vm.stop() }.buttonStyle(.kgOutline).fixedSize()
            }

        case .processing:
            VStack(spacing: 16) {
                MicButton(state: .processing)
                Text("Working out what that was…").font(KGFont.body).foregroundStyle(KGColor.ink2)
            }

        case .result(let transcript, let translation):
            VStack(spacing: 18) {
                ScrollView {
                    TranslationResultCard(translation: translation, original: transcript)
                }
                Button { vm.start() } label: {
                    Label("Listen again", systemImage: "mic.fill")
                }
                .buttonStyle(.kgPrimary)
            }

        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(KGColor.attention)
                Text(message)
                    .font(KGFont.body).foregroundStyle(KGColor.ink2).multilineTextAlignment(.center)
                Button("Try again") { vm.start() }.buttonStyle(.kgSecondary).fixedSize()
            }
        }
    }
}

#Preview {
    NavigationStack { ListenView() }
}
