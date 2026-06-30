#if canImport(UIKit)
import UIKit

/// Interactive overlay hosting one "minimize" button per tall expanded quote run (the blockquote underlay
/// is non-interactive, so the collapse button can't live there). Each button calls back with the run's
/// first-block index so the canvas can call `collapseQuoteRun(atIndex:)`.
@available(iOS 13.0, *)
final class QuoteCollapseControlsView: UIView {
    var onCollapse: ((Int) -> Void)?
    var accentColor: UIColor = .systemBlue { didSet { for b in pool.values { b.tintColor = accentColor } } }
    /// The collapse-button image (host-injected). `nil` ⇒ no button is shown (no fallback).
    var collapseImage: UIImage?
    private var pool: [Int: UIButton] = [:]   // keyed by block index

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// Hit-test only the buttons, so taps elsewhere fall through to the canvas (editing/selection).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        return v is UIButton ? v : nil
    }

    /// Reconciles the visible buttons against `runs`. Hidden (stale) buttons remain in the pool so their
    /// block-index → button mapping is reused when the run comes back into view.
    func sync(runs: [(blockIndex: Int, rect: CGRect)]) {
        var present = Set<Int>()
        if let image = collapseImage {
            for run in runs {
                present.insert(run.blockIndex)
                let btn = pool[run.blockIndex] ?? {
                    let b = UIButton(type: .system)
                    b.tintColor = accentColor
                    b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
                    pool[run.blockIndex] = b
                    addSubview(b)
                    return b
                }()
                btn.setImage(image, for: .normal)
                btn.tag = run.blockIndex
                btn.frame = run.rect
                btn.isHidden = false
            }
        }
        for (idx, btn) in pool where !present.contains(idx) { btn.isHidden = true }
    }

    @objc private func tapped(_ sender: UIButton) { onCollapse?(sender.tag) }
}
#endif
