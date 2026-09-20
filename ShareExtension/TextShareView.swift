import SwiftUI

/// The share extension's UI for translated **text**: a spinner, then the translation (prominent)
/// plus the original, or an error.
struct TextShareView: View {
    @ObservedObject var model: TextShareModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                KGColor.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Keyglot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done"), action: onClose)
                        .foregroundStyle(KGColor.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .working(let label):
            VStack(spacing: 16) {
                SpinnerRing()
                Text(label.isEmpty ? String(localized: "Translating…") : label)
                    .font(KGFont.body).foregroundStyle(KGColor.ink2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(KGColor.attention)
                Text(message)
                    .font(KGFont.body).multilineTextAlignment(.center).foregroundStyle(KGColor.ink2)
            }
            .padding().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .done(let original, let translation):
            ScrollView {
                TranslationResultCard(translation: translation, original: original)
                    .padding()
            }
        }
    }
}
