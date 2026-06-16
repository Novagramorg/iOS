import Foundation
import UIKit
import ComponentFlow

// A small green capsule "NEW" pill used as the titleBadgeComponent for
// ItemListSwitchItem rows that carry a new feature badge.
//
// Usage:
//   let badge = AnyComponent(FenixNewBadgeComponent(langCode: langCode))
//   ItemListSwitchItem(... titleBadgeComponent: badge ...)
//
// To retire the badge on a row: stop passing titleBadgeComponent (or pass nil).
// No build-number comparison, no UserDefaults — badge is visible until a developer
// removes it from the call site.

// Localised label text for the badge pill.
private enum FenixNewBadgeLabel {
    static func text(langCode: String) -> String {
        switch langCode {
        case "uz": return "YANGI"
        case "ru": return "НОВОЕ"
        default:   return "NEW"
        }
    }
}

// Fenixuz emerald — matches the brand green used elsewhere in the fork.
private let fenixEmerald = UIColor(red: 0.18, green: 0.74, blue: 0.44, alpha: 1.0)

public final class FenixNewBadgeComponent: Component {

    public typealias EnvironmentType = Empty

    let langCode: String

    public init(langCode: String) {
        self.langCode = langCode
    }

    public static func == (lhs: FenixNewBadgeComponent, rhs: FenixNewBadgeComponent) -> Bool {
        return lhs.langCode == rhs.langCode
    }

    public final class View: UIView {
        private let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            // Pill background — green capsule drawn at layout time via cornerRadius
            backgroundColor = fenixEmerald
            clipsToBounds = true

            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
                label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }

        required init?(coder: NSCoder) { nil }

        func update(component: FenixNewBadgeComponent, availableSize: CGSize) -> CGSize {
            label.text = FenixNewBadgeLabel.text(langCode: component.langCode)

            // Measure text to size the pill
            let textSize = label.sizeThatFits(CGSize(width: 60, height: 20))
            let pillW = ceil(textSize.width) + 10  // 5pt padding each side
            let pillH: CGFloat = 18
            layer.cornerRadius = pillH / 2
            return CGSize(width: pillW, height: pillH)
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
