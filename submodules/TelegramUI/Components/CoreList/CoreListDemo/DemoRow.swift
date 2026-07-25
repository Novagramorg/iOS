import UIKit

final class DemoListItem: CoreListItem {
    let id: UUID
    var identity: AnyHashable { id }
    let title: String
    let detail: String
    let accentColor: UIColor
    /// A height floor imposed by the item (item-derived content). The explicit init's default keeps the
    /// `minHeight` parameter optional, so the existing `DemoListItem(id:title:detail:accentColor:)`
    /// call sites still compile.
    let minHeight: CGFloat

    init(id: UUID, title: String, detail: String, accentColor: UIColor, minHeight: CGFloat = 0) {
        self.id = id
        self.title = title
        self.detail = detail
        self.accentColor = accentColor
        self.minHeight = minHeight
    }

    func view() -> (UIView & CoreListItemView) {
        DemoListItemView(title: title, detail: detail, accentColor: accentColor, minHeight: minHeight)
    }

    // Content equality (design 2026-05-31 §4). The engine matches rows by `identity` (= id); this
    // `isEqual` compares `minHeight` — the demo's only mutable content (title/detail/accentColor are
    // fixed per id, so this is equivalent to comparing all content). A same-id row whose minHeight
    // changed is NOT equal, so it reconciles + animates its height.
    func isEqual(to other: CoreListItem) -> Bool {
        guard let o = other as? DemoListItem else { return false }
        return o.id == id && o.minHeight == minHeight   // title/detail/accentColor are fixed per id in the demo
    }

    // Hand the reused/recycled view this item's new external state (minHeight; title/detail/accent are
    // fixed per id). This view's mechanics happen to leave its internal state (isExpanded/extraHeight)
    // alone on a minHeight change — a VIEW choice, not an engine contract.
    func apply(to view: UIView & CoreListItemView) {
        (view as? DemoListItemView)?.applyMinHeight(minHeight)
    }
}

final class DemoListItemView: UIView, CoreListItemView {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let pillView = UIView()

    private let titleText: String
    private let detailText: String
    private let accentColor: UIColor
    private var isExpanded = false
    /// Programmatic height growth (via `grow(by:)`) — orthogonal to the tap-driven `isExpanded`.
    /// Used by the demo's "Grow center" test button to trigger a self-update without going through
    /// the tap recognizer (taps are absorbed by `PhysicsScrollEngine` mid-deceleration; this
    /// affordance is the only way to trigger a mid-flight self-update for 4c manual testing).
    private var extraHeight: CGFloat = 0
    /// Item-derived height floor (set from `DemoListItem.minHeight`, reconfigured via `applyMinHeight`).
    /// Orthogonal to the view-only `isExpanded`/`extraHeight`; the natural/expanded/grown height still
    /// wins when larger.
    private var minHeight: CGFloat
    var onContentDidChange: ((Bool) -> Void)?

    init(title: String, detail: String, accentColor: UIColor, minHeight: CGFloat = 0) {
        self.titleText = title
        self.detailText = detail
        self.accentColor = accentColor
        self.minHeight = minHeight
        super.init(frame: .zero)

        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 1.0
        backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : .secondarySystemBackground
        }

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .label
        titleLabel.text = titleText

        detailLabel.font = .systemFont(ofSize: 14, weight: .regular)
        detailLabel.numberOfLines = 0
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = detailText
        detailLabel.isHidden = true

        pillView.layer.cornerRadius = 6
        pillView.layer.cornerCurve = .continuous
        pillView.backgroundColor = accentColor

        addSubview(pillView)
        addSubview(titleLabel)
        addSubview(detailLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleExpanded))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleExpanded() {
        isExpanded.toggle()
        detailLabel.isHidden = !isExpanded
        onContentDidChange?(true)
    }

    /// Programmatic height growth (for the demo's "Grow center" test button). Adds `additional`
    /// points to the row's `update(width:)` return value and signals the list to re-measure +
    /// animate via the same dirty-flush path that `toggleExpanded` uses.
    func grow(by additional: CGFloat) {
        extraHeight += additional
        onContentDidChange?(true)
    }

    /// Adopt the new item-derived height floor (content reconcile). This view's mechanic leaves its
    /// internal `isExpanded`/`extraHeight` state untouched on a minHeight change (a VIEW choice, not an
    /// engine contract). The next `update(width:)` reflects the new floor.
    func applyMinHeight(_ h: CGFloat) {
        minHeight = h
    }

    func update(width: CGFloat) -> CGFloat {
        let contentInsets = UIEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        let pillSize = CGSize(width: 12, height: 12)
        let labelWidth = max(0, width - contentInsets.left - contentInsets.right)
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height

        pillView.frame = CGRect(x: contentInsets.left, y: contentInsets.top + 2, width: pillSize.width, height: pillSize.height)
        titleLabel.frame = CGRect(x: contentInsets.left, y: contentInsets.top + pillSize.height + 10, width: labelWidth, height: titleHeight)

        var totalHeight = contentInsets.top + pillSize.height + 10 + titleHeight + contentInsets.bottom
        if isExpanded {
            let detailHeight = detailLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height
            detailLabel.frame = CGRect(x: contentInsets.left, y: titleLabel.frame.maxY + 8, width: labelWidth, height: detailHeight)
            totalHeight += 8 + detailHeight
        }

        return max(ceil(totalHeight + extraHeight), minHeight)
    }
}

extension DemoListItem {
    static func makeItems(count: Int = 180) -> [DemoListItem] {
        let accents: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemRed, .systemTeal, .systemIndigo]

        return (0..<count).map { index in
            let detail: String
            switch index % 4 {
            case 0: detail = "Only visible items are instantiated and measured."
            case 1: detail = "The list keeps a large scroll range and rebuilds the live window as needed."
            case 2: detail = "Nearby targets scroll through shared rows; distant targets use a one-window carousel."
            default: detail = "Overlapping windows reuse the same view instances for shared rows."
            }

            return DemoListItem(
                id: UUID(),
                title: "Row \(index)",
                detail: detail,
                accentColor: accents[index % accents.count]
            )
        }
    }
}
