import SwiftUI
import UIKit
import CoreText

/// Keyglot typography. Brand fonts (Instrument Sans + Instrument Serif) are bundled in
/// `Shared/Fonts/` and registered at runtime, so every target picks them up without an
/// `UIAppFonts` entry. Arabic/CJK fall back to the iOS system fonts. If a brand font ever fails to
/// register, everything degrades to the system font instead of breaking.
///
/// Instrument Sans is a variable font (wght 400–700); weights are selected via its `wght` axis.
/// Instrument Serif is display-only (headlines) and ships Regular + Italic.
enum KGFont {

    // MARK: Named styles (scaled with Dynamic Type)
    static var hero: Font    { serif(34, style: .largeTitle) }      // emotional H1
    static var title: Font   { sans(22, 600, style: .title2) }      // screen titles
    static var result: Font  { sans(19, 400, style: .title3) }      // translation body
    static var body: Font    { sans(16, 400, style: .body) }        // primary body
    static var row: Font     { sans(15, 400, style: .subheadline) } // list rows
    static var caption: Font { sans(12, 400, style: .caption1) }    // transcript labels
    static var chip: Font    { sans(10.5, 600, style: .caption2) }  // language autonyms
    static var eyebrow: Font { sans(11, 700, style: .caption2) }    // uppercase section labels

    // MARK: Builders

    /// Instrument Sans at an explicit weight (400–700), scaled for the given text style.
    static func sans(_ size: CGFloat, _ weight: CGFloat = 400, style: UIFont.TextStyle = .body) -> Font {
        Font(UIFontMetrics(forTextStyle: style).scaledFont(for: sansUIFont(size: size, weight: weight)))
    }

    /// Instrument Serif, scaled for the given text style.
    static func serif(_ size: CGFloat, italic: Bool = false, style: UIFont.TextStyle = .largeTitle) -> Font {
        Font(UIFontMetrics(forTextStyle: style).scaledFont(for: serifUIFont(size: size, italic: italic)))
    }

    // MARK: - UIFont plumbing

    private static let wghtAxis: UInt32 = 0x77676874  // 'wght'

    private static func sansUIFont(size: CGFloat, weight: CGFloat) -> UIFont {
        register()
        let variation: [UInt32: CGFloat] = [wghtAxis: weight]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Instrument Sans",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        // UIFont falls back to a system font (different familyName) if the name isn't registered.
        if font.familyName == "Instrument Sans" { return font }
        return .systemFont(ofSize: size, weight: systemWeight(weight))
    }

    private static func serifUIFont(size: CGFloat, italic: Bool) -> UIFont {
        register()
        let name = italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular"
        if let font = UIFont(name: name, size: size) { return font }
        // Fallback: the system serif design.
        let base = UIFont.systemFont(ofSize: size)
        if let d = base.fontDescriptor.withDesign(.serif) { return UIFont(descriptor: d, size: size) }
        return base
    }

    private static func systemWeight(_ w: CGFloat) -> UIFont.Weight {
        switch w {
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        default:     return .bold
        }
    }

    // MARK: - Registration (once per process)

    private static let didRegister: Bool = {
        for name in ["InstrumentSans", "InstrumentSerif-Regular", "InstrumentSerif-Italic"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    static func register() { _ = didRegister }
}

extension View {
    /// Uppercase, tracked section eyebrow (e.g. "TRANSLATION", "YOUR PLAN").
    func kgEyebrow(_ color: Color = KGColor.ink3) -> some View {
        font(KGFont.eyebrow)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(color)
    }
}
