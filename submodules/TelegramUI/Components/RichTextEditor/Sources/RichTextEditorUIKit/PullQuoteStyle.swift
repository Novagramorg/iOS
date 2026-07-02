#if canImport(UIKit)
import UIKit

/// Per-host geometry for pull-quote blocks. Every field defaults to the built-in look, so a host that never sets
/// `RichTextEditorView.pullQuoteStyle` is unchanged. Consolidates the constants introduced across the render tasks.
@available(iOS 13.0, *)
public struct PullQuoteStyle: Equatable {
    /// Interior horizontal padding: text→pill-edge on each side (points). Also the pill's horizontal breathing room.
    public var horizontalPadding: CGFloat
    /// Interior vertical padding: text→pill-edge top/bottom (points).
    public var verticalPadding: CGFloat
    /// Pill corner radius (points).
    public var cornerRadius: CGFloat
    /// Pill fill opacity (0…1).
    public var fillAlpha: CGFloat
    /// Corner quote-mark side length (points).
    public var markSize: CGFloat
    /// Inset of each corner mark from the pill's corner (points).
    public var markInset: CGFloat
    /// Minimum pill width (points) — the floor for a short/empty pull quote so the corner marks + placeholder fit.
    public var minWidth: CGFloat

    public init(horizontalPadding: CGFloat = 12, verticalPadding: CGFloat = 8,
                cornerRadius: CGFloat = 2.5, fillAlpha: CGFloat = 0.10,
                markSize: CGFloat = 16, markInset: CGFloat = 6, minWidth: CGFloat = 160) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.cornerRadius = cornerRadius
        self.fillAlpha = fillAlpha
        self.markSize = markSize
        self.markInset = markInset
        self.minWidth = minWidth
    }

    public static let `default` = PullQuoteStyle()
}
#endif
