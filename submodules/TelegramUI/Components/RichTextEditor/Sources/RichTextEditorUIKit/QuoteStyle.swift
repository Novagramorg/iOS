#if canImport(UIKit)
import UIKit

/// Per-host geometry for quote blocks. Every field defaults to the editor's built-in (reference-design)
/// look, so a host that never sets `RichTextEditorView.quoteStyle` is unchanged. The chat composer and the
/// article editor each assign their own before seeding the document (the compact-host knob convention).
@available(iOS 13.0, *)
public struct QuoteStyle: Equatable {
    /// Interior left padding (bar→text gap), in points. → `StyleSheet.quoteIndent`.
    public var leadingInset: CGFloat
    /// Interior right padding, in points (the text container narrows; the fill stays full width).
    /// → `StyleSheet.quoteTrailingInset`.
    public var trailingInset: CGFloat
    /// Paragraph spacing above each quote paragraph, in points. → `StyleSheet.quoteSpacingBefore`.
    public var spacingBefore: CGFloat
    /// Paragraph spacing below each quote paragraph, in points. → `StyleSheet.quoteSpacingAfter`.
    public var spacingAfter: CGFloat
    /// Width of the leading accent bar, in points. → `BlockquoteUnderlay`.
    public var barWidth: CGFloat
    /// Corner radius of the fill + bar, in points. → `BlockquoteUnderlay`.
    public var cornerRadius: CGFloat
    /// Opacity of the accent fill behind the quote (0…1). → `BlockquoteUnderlay`.
    public var fillAlpha: CGFloat

    public init(leadingInset: CGFloat = 16, trailingInset: CGFloat = 0,
                spacingBefore: CGFloat = 8, spacingAfter: CGFloat = 8,
                barWidth: CGFloat = 3, cornerRadius: CGFloat = 2.5, fillAlpha: CGFloat = 0.10) {
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.barWidth = barWidth
        self.cornerRadius = cornerRadius
        self.fillAlpha = fillAlpha
    }

    public static let `default` = QuoteStyle()
}
#endif
