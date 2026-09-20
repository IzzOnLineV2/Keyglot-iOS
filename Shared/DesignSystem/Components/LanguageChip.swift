import SwiftUI

/// A target-language chip: flag + native name (autonym). Used on the keyboard bar and in the Home
/// "your keyboard" summary. Idle = surface card; active = the Glot gradient with white text.
struct LanguageChip: View {
    enum ChipState { case idle, active, disabled }

    let flag: String
    let name: String
    var chipState: ChipState = .idle
    var height: CGFloat = 54

    private var isActive: Bool { chipState == .active }

    var body: some View {
        VStack(spacing: 3) {
            Text(flag).font(.system(size: 19))
            Text(name)
                .font(KGFont.chip)
                .foregroundStyle(isActive ? Color.white : KGColor.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: KGRadius.chip, style: .continuous)
                .strokeBorder(isActive ? KGColor.accent : .clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: KGRadius.chip, style: .continuous))
        .kgShadow(isActive ? .chipGlow : .card)
        .opacity(chipState == .disabled ? 0.5 : 1)
    }

    @ViewBuilder
    private var background: some View {
        if isActive {
            KGGradient.diagonal
        } else {
            KGColor.surface
        }
    }
}
