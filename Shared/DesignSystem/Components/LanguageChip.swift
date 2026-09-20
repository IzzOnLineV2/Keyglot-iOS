import SwiftUI

/// A target-language chip: flag + native name (autonym). Used on the keyboard bar and in the Home
/// "your keyboard" summary. Idle = surface card; active/working = the Glot gradient with white text
/// (working adds an animated shimmer sweep).
struct LanguageChip: View {
    enum ChipState { case idle, active, working, disabled }

    let flag: String
    let name: String
    var chipState: ChipState = .idle
    var height: CGFloat = 54

    private var onGradient: Bool { chipState == .active || chipState == .working }

    var body: some View {
        VStack(spacing: 3) {
            Text(flag).font(.system(size: 19))
            Text(name)
                .font(KGFont.chip)
                .foregroundStyle(onGradient ? Color.white : KGColor.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(background)
        .overlay {
            if chipState == .working { ShimmerOverlay() }
        }
        .overlay(
            RoundedRectangle(cornerRadius: KGRadius.chip, style: .continuous)
                .strokeBorder(chipState == .active ? KGColor.accent : .clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: KGRadius.chip, style: .continuous))
        .kgShadow(onGradient ? .chipGlow : .card)
        .opacity(chipState == .disabled ? 0.5 : 1)
    }

    @ViewBuilder
    private var background: some View {
        if onGradient { KGGradient.diagonal } else { KGColor.surface }
    }
}

/// A diagonal highlight that sweeps across a chip while it's "working".
private struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.55), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.6)
            .offset(x: phase * geo.size.width)
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
        }
        .allowsHitTesting(false)
    }
}
