import SwiftUI

/// The signature "Glot" gradient (cyan → violet → pink). Used sparingly: the mark, the active
/// language chip, the translation seam, and CTA buttons. Never a page background or behind text.
enum KGGradient {
    static let stops: [Gradient.Stop] = [
        .init(color: Color(hex: 0x22C3D6), location: 0.0),
        .init(color: Color(hex: 0x7A5BF0), location: 0.52),
        .init(color: Color(hex: 0xF0609B), location: 1.0),
    ]

    /// Mark, active chip, CTA buttons (~110–135°).
    static let diagonal = LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)

    /// The 2pt translation "seam" (90°). Does NOT mirror in RTL — reads outward from the middle.
    static let seam = LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)

    /// Wider gradient for the animated shimmer on a "working" chip (animate the fill's offset).
    static let shimmer = LinearGradient(
        colors: [Color(hex: 0x22C3D6), Color(hex: 0x7A5BF0), Color(hex: 0xF0609B), Color(hex: 0x22C3D6)],
        startPoint: .leading, endPoint: .trailing
    )

    /// The proposed app-icon gradient (150°): heritage blue → accent → magenta.
    static let icon = LinearGradient(
        colors: [Color(hex: 0x2673E6), Color(hex: 0x6B4EF0), Color(hex: 0xC44BC8)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
