#if canImport(UIKit)
import UIKit

/// The per-paragraph line-layout-and-draw engine seam. The editor is coordinate-free and talks to text
/// layout ONLY through this offset-based (`Int`) surface — never the underlying TextKit types — so the
/// concrete engine is swappable:
/// - `BlockLayout` (TextKit 2, `@available(iOS 13.0, *)`) is the production implementation;
/// - `BlockLayoutTK1` (TextKit 1, iOS 7+) is the iOS-15/16 back-port implementation.
///
/// Selected by `makeBlockLayout(...)`: an `RTE_TK1` build forces TextKit 1; otherwise TextKit 2 is used
/// where available, falling back to TextKit 1 below iOS 17. (This factory + protocol is also what the real
/// iOS-15 back-port needs — the seam was introduced as a feasibility spike, see the project CLAUDE.md.)
protocol BlockLayoutEngine: AnyObject {
    var attributedString: NSAttributedString { get set }
    var length: Int { get }
    var renderVersion: Int { get }
    var boundingHeight: CGFloat { get }
    var firstLineBaselineFromTop: CGFloat? { get }
    /// The underlying mutable text storage — abstracts TextKit 2's `contentStorage.textStorage`.
    var backingStorage: NSTextStorage? { get }
    /// The layout container's width — abstracts TextKit 2's `container.size.width`.
    var containerWidth: CGFloat { get }

    func bumpRenderVersion()
    func setWidth(_ width: CGFloat)
    func caretRect(atOffset offset: Int) -> CGRect
    func selectionRects(start: Int, end: Int) -> [CGRect]
    func selectionFillRects(start: Int, end: Int, fillTrailingLine: Bool) -> [CGRect]
    func attachmentBox(at offset: Int) -> CGRect?
    func closestOffset(toPoint point: CGPoint) -> Int
    func drawText(in ctx: CGContext, at origin: CGPoint)
    func replace(start: Int, end: Int, with string: NSAttributedString)
    func setGhostForeground(_ color: UIColor?, start: Int, end: Int)
    @discardableResult func setSpoilerHidden(_ ranges: [NSRange]) -> Bool
}

/// Runtime control over which layout engine `makeBlockLayout` builds — for verifying the iOS-15 back-port
/// (TextKit 1) path inside the running app on a modern OS, without a special build.
public enum BlockLayoutBackend {
    /// Force the TextKit-1 engine. Set this manually (e.g. from a debug hook) to `true` before the editor
    /// builds its blocks — it's read at block-construction time, so reopen the composer to apply.
    public static var forceTextKit1: Bool = {
        #if DEBUG && false
        return true
        #else
        return false
        #endif
    }()
}

/// Constructs the active layout engine. `RTE_TK1` (the back-port build) forces TextKit 1; otherwise the
/// runtime `BlockLayoutBackend.forceTextKit1` override wins, else TextKit 2 on iOS 17+ / TextKit 1 below.
func makeBlockLayout(attributedString: NSAttributedString, width: CGFloat) -> BlockLayoutEngine {
    #if RTE_TK1
    return BlockLayoutTK1(attributedString: attributedString, width: width)
    #else
    if BlockLayoutBackend.forceTextKit1 {
        return BlockLayoutTK1(attributedString: attributedString, width: width)
    }
    if #available(iOS 16.0, *) {
        return BlockLayout(attributedString: attributedString, width: width)
    } else {
        return BlockLayoutTK1(attributedString: attributedString, width: width)
    }
    #endif
}
#endif
