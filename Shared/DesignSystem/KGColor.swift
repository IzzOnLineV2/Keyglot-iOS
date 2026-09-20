import SwiftUI
import UIKit

/// Keyglot design-system colors (from the Claude Design redesign). Defined in code as dynamic
/// light/dark `Color`s so every target (app, keyboard, share, widget) shares them without
/// duplicating an asset catalog.
///
/// Palette rule: the warm neutral base carries the UI; the "Glot" gradient (`KGGradient`) is used
/// only for the mark, the active language chip, the translation seam, and CTA buttons — never as a
/// page background or behind body text.
enum KGColor {
    // Surfaces
    static let canvas        = dyn(0xFAF8F6, 0x0F0E13)   // screen background
    static let surface       = dyn(0xFFFFFF, 0x1A1822)   // cards, idle chips
    static let fill          = dyn(0xF3F0EC, 0x262231)   // secondary buttons, idle chips (kit)
    static let barButtonFill = dyn(0xF1EEEA, 0x1E1B27)   // keyboard-bar buttons, "Original" card
    static let border        = dyn(0xE6E1DB, 0x2E2A3B)   // hairlines (1px)

    // Text
    static let ink   = dyn(0x17151C, 0xF7F4FA)           // primary text / "ink" button background
    static let onInk = dyn(0xFFFFFF, 0x17151C)           // text/icon ON an ink background (inverts in dark)
    static let ink2  = dyn(0x6B6572, 0xA79FB4)           // secondary text, autonyms, captions
    static let ink3  = dyn(0x9A939F, 0x756E82)           // tertiary / eyebrow muted / placeholders

    // Brand
    static let accent    = dyn(0x6B4EF0, 0x9E86FF)       // eyebrows, active chip, focus, links
    static let accentTint = dyn(0xEDE9FE, 0x241C36)      // purple tint fill (selected chip / hint)
    static let heritage  = solid(0x2673E6)               // icon anchor / iOS-native tint

    // Semantic
    static let success   = dyn(0x1E9E6A, 0x4ADE9B)
    static let successBg = dyn(0xE6F6EF, 0x15301F)
    static let attention   = dyn(0xC87213, 0xE0A15A)
    static let attentionBg = dyn(0xFDF4E8, 0x2E2417)
    static let error   = dyn(0xC4382F, 0xE0736A)
    static let errorBg = dyn(0xFBEDEC, 0x2E1A18)
    static let record  = solid(0xD93B6B)                 // live mic only

    // MARK: - Builders

    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
    static func solid(_ rgb: UInt32) -> Color { Color(UIColor(rgb: rgb)) }
}

extension UIColor {
    /// 0xRRGGBB.
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// 0xRRGGBB — for one-off design values (gradient stops, etc.). Prefer `KGColor` tokens.
    init(hex: UInt32) { self.init(UIColor(rgb: hex)) }
}
