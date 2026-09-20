import SwiftUI

/// The 2pt "translation seam" — the Glot gradient reading outward from the middle. The visual
/// metaphor for "two scripts meeting". Does NOT mirror in RTL.
struct SeamDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(KGGradient.seam)
            .frame(height: 2)
            .environment(\.layoutDirection, .leftToRight)
    }
}
