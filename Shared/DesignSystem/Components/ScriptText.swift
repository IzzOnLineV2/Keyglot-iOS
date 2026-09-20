import SwiftUI
import UIKit

/// Text that adapts to its script: Arabic (and other RTL) content is rendered right-to-left,
/// trailing-aligned, a touch larger (+8%) and with looser leading, so transcripts and translations
/// in Arabic/Darija read naturally instead of being cramped left-to-right. Latin/CJK render normally.
///
/// Instrument Sans has no Arabic glyphs, so CoreText substitutes the system Arabic font per run —
/// we only need to fix size + direction here.
struct ScriptText: View {
    let text: String
    var size: CGFloat
    var weight: CGFloat = 400
    var style: UIFont.TextStyle = .body
    var color: Color = KGColor.ink

    private var isRTL: Bool { text.isMostlyArabic }

    var body: some View {
        Text(text)
            .font(KGFont.sans(isRTL ? size * 1.08 : size, weight, style: style))
            .foregroundStyle(color)
            .lineSpacing(isRTL ? 3 : 0)
            .multilineTextAlignment(isRTL ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
            .textSelection(.enabled)
    }
}

extension String {
    /// True when the string is predominantly Arabic-script (so it should read RTL).
    var isMostlyArabic: Bool {
        var arabic = 0
        var letters = 0
        for scalar in unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            letters += 1
            let v = scalar.value
            if (0x0600...0x06FF).contains(v) || (0x0750...0x077F).contains(v) ||
               (0x08A0...0x08FF).contains(v) || (0xFB50...0xFDFF).contains(v) ||
               (0xFE70...0xFEFF).contains(v) {
                arabic += 1
            }
        }
        return letters > 0 && arabic * 2 >= letters
    }
}
