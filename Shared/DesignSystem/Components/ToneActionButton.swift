import SwiftUI

/// A tone/rewrite action chip: glyph + short label (✨ Improve, 💼 Formal, …). Idle = neutral bar
/// fill; active = ink fill with white label.
struct ToneActionButton: View {
    let glyph: String
    let label: LocalizedStringKey
    var isActive = false
    var isDisabled = false
    var height: CGFloat = 48

    var body: some View {
        VStack(spacing: 2) {
            Text(glyph).font(.system(size: 16))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? KGColor.onInk : KGColor.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(isActive ? AnyShapeStyle(KGColor.ink) : AnyShapeStyle(KGColor.barButtonFill))
        .clipShape(RoundedRectangle(cornerRadius: KGRadius.tone, style: .continuous))
        .opacity(isDisabled ? 0.5 : 1)
    }
}
