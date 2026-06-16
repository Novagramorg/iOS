#if canImport(UIKit)
import UIKit

/// Back-most, non-drawing container that hosts one stretchable-image `UIImageView` per blockquote run,
/// so the run's rounded fill + leading bar render BEHIND the quote paragraphs' (clear-backed) block
/// views. A resizable image stretches a tiny bitmap via the layer's `contentsCenter` on the GPU, so a
/// run-tall frame allocates no large backing store — the size-safe replacement for drawing the fill
/// into the (document-sized) canvas context.
@available(iOS 17.0, *)
final class BlockquoteUnderlay: UIView {
    private var pool: [Int: UIImageView] = [:]   // keyed by run index (stable order along the document)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: BlockquoteUnderlay, _: UITraitCollection) in
            view.rebuildFillForAppearanceChange()
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// A system appearance switch (light↔dark) only fires trait callbacks, not `layoutSubviews`, so the
    /// cached (appearance-baked) fill image would otherwise go stale until the next relayout. Rebuild it
    /// and re-apply to the visible views so the quote fill tracks the system appearance live.
    private func rebuildFillForAppearanceChange() {
        cachedImage = nil
        let image = fillImage()
        for iv in pool.values where !iv.isHidden { iv.image = image }
    }

    /// The bar + fill color. Defaults to `.systemBlue` (prior behavior); set from the editor theme's accent.
    var accentColor: UIColor = .systemBlue {
        didSet {
            cachedImage = nil
            rebuildFillForAppearanceChange()
        }
    }

    /// The cached resizable fill+bar image, rebuilt on a trait change (light/dark, tint).
    private var cachedImage: UIImage?
    private var cachedTraits: UITraitCollection?

    private func fillImage() -> UIImage {
        if let img = cachedImage, cachedTraits == traitCollection { return img }
        let radius = DocumentCanvasView.blockquoteCornerRadius
        let bar: CGFloat = 3
        let cap = max(radius, bar) + 1
        let side = cap * 2 + 2
        let size = CGSize(width: side, height: side)
        let img = UIGraphicsImageRenderer(size: size).image { c in
            let ctx = c.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            accentColor.withAlphaComponent(0.10).setFill(); path.fill()
            ctx.saveGState(); path.addClip()
            accentColor.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: bar, height: size.height))
            ctx.restoreGState()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: cap, left: cap, bottom: cap, right: cap),
                         resizingMode: .stretch)
        cachedImage = img; cachedTraits = traitCollection
        return img
    }

    /// Reconciles one image view per run rect (canvas coords). Reuses pooled views by index.
    func sync(runFills: [CGRect]) {
        let image = fillImage()
        for (i, fill) in runFills.enumerated() {
            let iv = pool[i] ?? {
                let v = UIImageView(); v.isUserInteractionEnabled = false
                pool[i] = v; addSubview(v); return v
            }()
            iv.image = image
            iv.frame = fill
            iv.isHidden = false
        }
        for (i, iv) in pool where i >= runFills.count { iv.isHidden = true }
    }
}
#endif
