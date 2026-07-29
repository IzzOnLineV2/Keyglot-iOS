import SwiftUI

/// The share extension's UI for translated **text**: a spinner, then the translation (prominent)
/// plus the original, or an error.
struct TextShareView: View {
    @ObservedObject var model: TextShareModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Keyglot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done"), action: onClose)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .working(let label):
            VStack(spacing: 14) {
                ProgressView()
                Text(label.isEmpty ? String(localized: "Working…") : label)
                    .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text(message)
                    .font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .padding().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .done(let original, let translation):
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(title: String(localized: "Translation"), text: translation, prominent: true)
                    section(title: String(localized: "Original"), text: original, prominent: false)
                }
                .padding()
            }
        }
    }

    private func section(title: String, text: String, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            Text(text)
                .font(prominent ? .body : .callout)
                .foregroundStyle(prominent ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
