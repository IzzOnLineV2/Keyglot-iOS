import SwiftUI

/// "Listen & translate": opens (from Settings or the widget deep link), starts recording
/// immediately, auto-stops on silence, and shows Gemini's translation of what it heard.
struct ListenView: View {
    @StateObject private var vm = ListenViewModel()

    var body: some View {
        VStack(spacing: 20) {
            languagePicker
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(Text("Listen & translate"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if vm.phase == .idle { vm.start() } }
        .onDisappear { vm.cancel() }
    }

    // MARK: - Language

    private var languagePicker: some View {
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
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text("Audio language")
                Spacer()
                Text(VoiceLanguage.option(for: vm.selectedID).name)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle:
            micButton(active: false, label: Text("Tap to listen")) { vm.start() }

        case .recording:
            VStack(spacing: 16) {
                micButton(active: true, label: Text("Listening…")) { vm.stop() }
                Button(role: .cancel) { vm.stop() } label: {
                    Text("Stop").font(.headline)
                }
                .buttonStyle(.bordered)
            }

        case .processing:
            VStack(spacing: 14) {
                ProgressView()
                Text("Translating…").foregroundStyle(.secondary)
            }

        case .result(let transcript, let translation):
            VStack(spacing: 18) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section(title: Text("Translation"), text: translation, prominent: true)
                        section(title: Text("Original"), text: transcript, prominent: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { vm.start() } label: {
                    Label("Listen again", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            }

        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button { vm.start() } label: { Text("Try again").font(.headline) }
                    .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Pieces

    private func micButton(active: Bool, label: Text, action: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(active ? Color.red : Color.blue)
                        .frame(width: 120, height: 120)
                        .scaleEffect(active ? 1 + vm.level * 0.35 : 1)
                        .shadow(color: (active ? Color.red : Color.blue).opacity(0.4), radius: 16)
                        .animation(.easeOut(duration: 0.12), value: vm.level)
                    Image(systemName: active ? "waveform" : "mic.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            label
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func section(title: Text, text: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            title
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(text)
                .font(prominent ? .title3 : .callout)
                .foregroundStyle(prominent ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationStack { ListenView() }
}
