import SwiftUI

/// The shared result surface: the translation up top (prominent, on a white card, underlined by
/// the seam) and the original transcript below (secondary). Used by the voice-note sheet, the
/// in-app Listen result, and the keyboard clipboard panel.
struct TranslationResultCard: View {
    let translation: String
    let original: String
    var translationLabel: LocalizedStringKey = "Translation"
    var originalLabel: LocalizedStringKey = "Original"

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(translationLabel).kgEyebrow(KGColor.accent)
                Text(translation)
                    .font(KGFont.result)
                    .foregroundStyle(KGColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                SeamDivider()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.surface, in: RoundedRectangle(cornerRadius: KGRadius.card, style: .continuous))
            .kgShadow(.result)

            VStack(alignment: .leading, spacing: 6) {
                Text(originalLabel).kgEyebrow(KGColor.ink3)
                Text(original)
                    .font(KGFont.body)
                    .foregroundStyle(KGColor.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.barButtonFill, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
        }
    }
}
