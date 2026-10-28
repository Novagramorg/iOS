import UIKit

// The Novagram logo for the center of the login QR code, like on Android:
// the app icon cut to a blue circle, with a transparent ring around it so the
// QR's white background separates the logo from the modules.
public enum NovagramQrLogo {
    public static let image: UIImage? = {
        // novagram_logo is the app icon (rounded square) the intro screen already shows
        guard let logo = UIImage(named: "novagram_logo") else {
            return nil
        }
        let side: CGFloat = 120.0
        // qrCode() fits the image into the cleared center, so this ring is the white margin
        let ringWidth: CGFloat = side * 0.08
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let circleRect = CGRect(x: 0.0, y: 0.0, width: side, height: side).insetBy(dx: ringWidth, dy: ringWidth)
            UIBezierPath(ovalIn: circleRect).addClip()
            logo.draw(in: circleRect)
        }
    }()
}
