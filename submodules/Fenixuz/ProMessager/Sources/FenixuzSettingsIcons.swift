import Foundation
import UIKit

/// Telegram Settings ekranidagi rangli kvadrat ikon ko'rinishida SF Symbol asosida ikon yaratadi.
/// Apple's iOS Settings va Telegram'ning standart row-icon dizaynini takrorlaydi:
/// 30×30 dp, 7dp burchak, to'liq rangli fon, oq SF Symbol o'rtada.
public enum FenixuzIconColor {
    case red, green, blue, lightBlue, teal, orange, purple, pink, gray, violet, yellow, gold

    var uiColor: UIColor {
        switch self {
        case .red:       return UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1.0)  // FF453A
        case .green:     return UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)  // 34C759
        case .blue:      return UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)  // 0079FF
        case .lightBlue: return UIColor(red: 0.20, green: 0.68, blue: 0.90, alpha: 1.0)  // 32ADE6
        case .teal:      return UIColor(red: 0.00, green: 0.78, blue: 0.75, alpha: 1.0)  // 00C7BE
        case .orange:    return UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1.0)  // FF9F0A
        case .purple:    return UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)  // AF52DE
        case .pink:      return UIColor(red: 1.00, green: 0.18, blue: 0.33, alpha: 1.0)  // FF2D55
        case .gray:      return UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)  // 8E8E93
        case .violet:    return UIColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1.0)  // 5E5CE6
        case .yellow:    return UIColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0)  // FFCC00
        case .gold:      return UIColor(red: 0.83, green: 0.69, blue: 0.22, alpha: 1.0)  // D4AF37 — tilla
        }
    }
}

public func fenixuzSettingsIcon(systemName: String, color: FenixuzIconColor) -> UIImage? {
    let size = CGSize(width: 30, height: 30)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let bgRect = CGRect(origin: .zero, size: size)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 7)
        color.uiColor.setFill()
        bgPath.fill()

        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            if let symbol = UIImage(systemName: systemName, withConfiguration: cfg) {
                let symbolSize = symbol.size
                let drawSize = CGSize(width: min(symbolSize.width, 20), height: min(symbolSize.height, 20))
                let drawRect = CGRect(
                    x: (size.width - drawSize.width) / 2,
                    y: (size.height - drawSize.height) / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                let tinted = symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                tinted.draw(in: drawRect)
            }
        }
    }
}
