#if canImport(UIKit)
import UIKit
#if !SWIFT_PACKAGE
import AppBundle
#endif

/// Non-interactive overlay hosting two tinted quote-mark image views per pull-quote pill: an opening mark at the
/// pill's top-left and a closing mark (rotated 180°) at the bottom-right. The pill fill is drawn by the barless
/// `pullQuoteUnderlay`; the marks sit above it. Image is the app's ReplyQuoteIcon (template, tinted to the accent);
/// nil under SwiftPM (no bundled asset), so Demo/tests show no glyph but geometry is still driven.
@available(iOS 13.0, *)
final class PullQuoteMarksView: UIView {
    var accentColor: UIColor = .systemBlue { didSet { for (o, c) in pool { o.tintColor = accentColor; c.tintColor = accentColor } } }
    private var pool: [(open: UIImageView, close: UIImageView)] = []

    private static let markImage: UIImage? = {
        #if SWIFT_PACKAGE
        return nil
        #else
        return UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon")?.withRenderingMode(.alwaysTemplate)
        #endif
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false   // decorative — never intercept touches
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Reconciles two image views per pill. Extra pooled views are hidden.
    func sync(marks: [(open: CGRect, close: CGRect)]) {
        let image = PullQuoteMarksView.markImage
        for (i, m) in marks.enumerated() {
            let pair = i < pool.count ? pool[i] : {
                let o = UIImageView(); let c = UIImageView()
                o.contentMode = .scaleAspectFit; c.contentMode = .scaleAspectFit
                o.tintColor = accentColor; c.tintColor = accentColor
                c.transform = CGAffineTransform(rotationAngle: .pi)   // closing mark
                addSubview(o); addSubview(c)
                pool.append((o, c))
                return (o, c)
            }()
            pair.open.image = image; pair.close.image = image
            pair.open.frame = m.open; pair.close.frame = m.close
            pair.open.isHidden = false; pair.close.isHidden = false
        }
        for i in marks.count..<pool.count { pool[i].open.isHidden = true; pool[i].close.isHidden = true }
    }
}
#endif
