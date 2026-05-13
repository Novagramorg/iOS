import Foundation
import UIKit

// Fenixuz brand colors — source: https://fenixuz.uz/assets/css/style.css
// "Brand palette (P2-8) — shared with vipads.uz so the brands feel related"
//
// Bu central palette. Barcha Fenixuz moduli (IntroTheme, ChatLock, Tasks, etc.)
// shu yerdan rang oladi. Hech qachon hard-code qilingan hex'lar boshqa joyda.

public enum FenixuzBrandColors {
    // MARK: - Brand greens (signature)
    public static let brand50  = UIColor(rgb: 0xECFDF5)
    public static let brand100 = UIColor(rgb: 0xD1FAE5)
    public static let brand300 = UIColor(rgb: 0x6EE7B7)
    public static let brand400 = UIColor(rgb: 0x34D399)
    public static let brand500 = UIColor(rgb: 0x10B981)   // Primary brand
    public static let brand600 = UIColor(rgb: 0x059669)   // Primary hover
    public static let brand700 = UIColor(rgb: 0x047857)   // Primary deep
    public static let brand900 = UIColor(rgb: 0x064E3B)

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
    public static var primary:      UIColor { brand600 }   // CTA buttons
    public static var primaryLight: UIColor { brand500 }   // hover / pressed
    public static var primaryDeep:  UIColor { brand700 }
    public static var primaryAccent: UIColor { brand500 }  // text accent
}

// MARK: - UIColor convenience

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >>  8) & 0xFF) / 255.0,
            blue:  CGFloat( rgb        & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
