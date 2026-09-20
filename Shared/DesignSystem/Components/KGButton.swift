import SwiftUI

/// Primary CTA — ink fill, white label (52pt).
struct KGPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(KGColor.onInk)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(KGColor.ink, in: RoundedRectangle(cornerRadius: KGRadius.cta, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Gradient CTA — the Glot gradient, white label (52pt). For the paywall's subscribe action.
struct KGGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: 16.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(KGGradient.diagonal, in: RoundedRectangle(cornerRadius: KGRadius.cta, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

/// Secondary — neutral fill, ink label.
struct KGSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(KGColor.ink)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(KGColor.fill, in: RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outline — hairline border, ink label.
struct KGOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(KGColor.ink)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous)
                    .strokeBorder(KGColor.border, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == KGPrimaryButtonStyle {
    static var kgPrimary: KGPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == KGGradientButtonStyle {
    static var kgGradient: KGGradientButtonStyle { .init() }
}
extension ButtonStyle where Self == KGSecondaryButtonStyle {
    static var kgSecondary: KGSecondaryButtonStyle { .init() }
}
extension ButtonStyle where Self == KGOutlineButtonStyle {
    static var kgOutline: KGOutlineButtonStyle { .init() }
}
