import Foundation
import UIKit

// Fenixuz brand colors — source: https://fenixuz.uz/assets/css/style.css
// "Brand palette (P2-8) — shared with vipads.uz so the brands feel related"
//
// Bu central palette. Barcha Fenixuz moduli (IntroTheme, ChatLock, Tasks, etc.)
// shu yerdan rang oladi. Hech qachon hard-code qilingan hex'lar boshqa joyda.

public enum FenixuzBrandColors {
    // MARK: - Brand blues (Novagram signature) — matches the app icon's blue
    public static let brand50  = UIColor(rgb: 0xEAF6FF)
    public static let brand100 = UIColor(rgb: 0xCFE9FF)
    public static let brand300 = UIColor(rgb: 0x7CC3FD)
    public static let brand400 = UIColor(rgb: 0x36A8FA)
    public static let brand500 = UIColor(rgb: 0x0A9BF5)   // Primary brand (Novagram blue)
    public static let brand600 = UIColor(rgb: 0x0A85E8)   // Primary hover / CTA button
    public static let brand700 = UIColor(rgb: 0x086FC6)   // Primary deep
    public static let brand900 = UIColor(rgb: 0x07406F)

    // MARK: - Ink (dark text / dark backgrounds)
    public static let inkBase = UIColor(rgb: 0x0F1115)    // Dark bg (dark mode)
    public static let ink900  = UIColor(rgb: 0x0B1220)
    public static let ink800  = UIColor(rgb: 0x111827)
    public static let ink700  = UIColor(rgb: 0x1F2937)
    public static let ink600  = UIColor(rgb: 0x374151)
    public static let ink500  = UIColor(rgb: 0x6B7280)
    public static let ink400  = UIColor(rgb: 0x9CA3AF)
    public static let ink300  = UIColor(rgb: 0xD1D5DB)
    public static let ink200  = UIColor(rgb: 0xE5E7EB)
    public static let ink100  = UIColor(rgb: 0xF3F4F6)
    public static let ink50   = UIColor(rgb: 0xF9FAFB)

    // MARK: - Accents
    public static let accentAmber = UIColor(rgb: 0xF59E0B)
    public static let destructive = UIColor(rgb: 0xDC2626)
    public static let destructiveDark = UIColor(rgb: 0xB91C1C)

    // MARK: - Semantic aliases (use these in UI code; values may evolve)
    public static var primary: UIColor { brand600 }   // CTA buttons
    public static var primaryLight: UIColor { brand500 }   // hover / pressed
    public static var primaryDeep: UIColor { brand700 }
    public static var primaryAccent: UIColor { brand500 }  // text accent

    // MARK: - White / light-theme accent (Feature #23)
    //
    // Used when the user turns on "Brand accent in light theme" in Fenix Settings.
    // We re-use brand500 (Novagram blue #0A9BF5) as the accent — same hue family as the
    // login screen so the brand stays coherent across dark & light modes.
    // Light-theme specific tones for tinting tappable elements and highlights.
    public static let lightThemeAccent: UIColor = brand500   // #0A9BF5 — primary tint
    // Raw RGB of lightThemeAccent (== brand500). The theme engine's
    // PresentationThemeAccentColor.accentColor wants a UInt32, not a UIColor.
    public static let lightThemeAccentValue: UInt32 = 0x0A9BF5
    public static let lightThemeAccentLight: UIColor = brand100   // #CFE9FF — selection bg, badge fill
    public static let lightThemeAccentDeep: UIColor = brand600   // #0A85E8 — pressed / active state
}

// MARK: - UIColor convenience

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >>  8) & 0xFF) / 255.0,
            blue: CGFloat( rgb        & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
