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
                ScriptText(text: translation, size: 19, style: .title3, color: KGColor.ink)
                SeamDivider()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.surface, in: RoundedRectangle(cornerRadius: KGRadius.card, style: .continuous))
            .kgShadow(.result)

            VStack(alignment: .leading, spacing: 6) {
                Text(originalLabel).kgEyebrow(KGColor.ink3)
                ScriptText(text: original, size: 16, style: .body, color: KGColor.ink2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.barButtonFill, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
        }
    }
}
