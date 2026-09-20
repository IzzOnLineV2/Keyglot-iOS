import SwiftUI

/// Corner radii from the redesign.
enum KGRadius {
    static let sm: CGFloat = 10
    static let tone: CGFloat = 12
    static let chip: CGFloat = 13
    static let button: CGFloat = 14
    static let cta: CGFloat = 15
    static let group: CGFloat = 18
    static let card: CGFloat = 20
    static let hero: CGFloat = 22
    static let sheet: CGFloat = 26
    static let pill: CGFloat = 99
}

/// Spacing / gutter grid (6–8pt base).
enum KGSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Soft elevation presets.
struct KGShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card   = KGShadow(color: Color(hex: 0x17151C).opacity(0.06), radius: 10, x: 0, y: 2)
    static let result = KGShadow(color: Color(hex: 0x17151C).opacity(0.07), radius: 14, x: 0, y: 3)
    static let bar    = KGShadow(color: Color(hex: 0x17151C).opacity(0.10), radius: 24, x: 0, y: 8)
    static let chipGlow = KGShadow(color: Color(hex: 0x6B4EF0).opacity(0.30), radius: 10, x: 0, y: 3)
    static let micIdle  = KGShadow(color: Color(hex: 0x17151C).opacity(0.22), radius: 34, x: 0, y: 14)
    static let micLive  = KGShadow(color: Color(hex: 0xD93B6B).opacity(0.40), radius: 34, x: 0, y: 14)
}

extension View {
    func kgShadow(_ s: KGShadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}
