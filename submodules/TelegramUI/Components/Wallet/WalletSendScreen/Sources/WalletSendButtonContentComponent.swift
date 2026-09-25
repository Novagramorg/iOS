import UIKit
import Display
import ComponentFlow
import AnimatedTextComponent

final class WalletSendButtonContentComponent: Component {
    let title: String
    let subtitle: String?
    let color: UIColor
    let isVisible: Bool

    init(title: String, subtitle: String?, color: UIColor, isVisible: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.isVisible = isVisible
    }

    static func ==(lhs: WalletSendButtonContentComponent, rhs: WalletSendButtonContentComponent) -> Bool {
        return lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.color == rhs.color
            && lhs.isVisible == rhs.isVisible
    }

    private static func textItems(_ text: String) -> [AnimatedTextComponent.Item] {
        var items: [AnimatedTextComponent.Item] = []
        var wordIndex = 0

        func appendWords(_ value: Substring, part: String) {
            var start = value.startIndex
            while start < value.endIndex {
                let isWhitespace = value[start].isWhitespace
                let end = value[start...].firstIndex(where: { $0.isWhitespace != isWhitespace }) ?? value.endIndex
                let id: String
                if isWhitespace {
                    id = "\(part)-space-\(wordIndex)"
                } else {
                    id = "word-\(wordIndex)"
                    wordIndex += 1
                }
                items.append(.init(id: id, content: .text(String(value[start..<end]))))
                start = end
            }
        }

        // Word identities do not depend on whether an amount is present. Keep words
        // breakable so Gram ↔ Grams preserves the common letters and only animates s.
        if let firstDigit = text.rangeOfCharacter(from: .decimalDigits),
           let lastDigit = text.rangeOfCharacter(from: .decimalDigits, options: .backwards) {
            appendWords(text[..<firstDigit.lowerBound], part: "prefix")
            items.append(.init(id: "amount", content: .text(String(text[firstDigit.lowerBound..<lastDigit.upperBound]))))
            appendWords(text[lastDigit.upperBound...], part: "suffix")
        } else {
            appendWords(text[...], part: "prefix")
        }
        return items
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private var component: WalletSendButtonContentComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.isUserInteractionEnabled = false
            self.isAccessibilityElement = true
            self.accessibilityTraits = .staticText
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletSendButtonContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            var textTransition: ComponentTransition = .immediate
            if let previous = self.component, previous.isVisible, component.isVisible, self.window != nil,
               !UIAccessibility.isReduceMotionEnabled {
                if previous.title != component.title || previous.subtitle != component.subtitle {
                    textTransition = .easeInOut(duration: 0.22)
                } else {
                    textTransition = transition
                }
            }
            self.component = component
            self.accessibilityLabel = [component.title, component.subtitle].compactMap { $0 }.joined(separator: ", ")

            // Measure at the normal font size, then fit long amounts without truncation.
            let textContainerSize = CGSize(width: 10000.0, height: availableSize.height)
            let titleSize = self.title.update(
                transition: textTransition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(17.0),
                    color: component.color,
                    items: WalletSendButtonContentComponent.textItems(component.title),
                    noDelay: true,
                    blur: true,
                    useTransitionAnimation: true
                )),
                environment: {},
                containerSize: textContainerSize
            )
            let titleScale = min(1.0, availableSize.width / max(1.0, titleSize.width))

            var subtitleSize = CGSize.zero
            var subtitleScale: CGFloat = 1.0
            if let subtitle = component.subtitle {
                subtitleSize = self.subtitle.update(
                    transition: self.subtitle.view == nil ? .immediate : textTransition,
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.medium(11.0),
                        color: component.color.withAlphaComponent(0.7),
                        items: WalletSendButtonContentComponent.textItems(subtitle),
                        noDelay: true,
                        blur: true,
                        useTransitionAnimation: true
                    )),
                    environment: {},
                    containerSize: textContainerSize
                )
                subtitleScale = min(1.0, availableSize.width / max(1.0, subtitleSize.width))
            }

            let titleHeight = titleSize.height * titleScale
            let subtitleHeight = subtitleSize.height * subtitleScale
            let spacing: CGFloat = component.subtitle == nil ? 0.0 : 1.0
            let contentHeight = titleHeight + spacing + subtitleHeight
            let contentY = floorToScreenPixels((availableSize.height - contentHeight) / 2.0)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.accessibilityElementsHidden = true
                    self.addSubview(titleView)
                }
                textTransition.setBounds(view: titleView, bounds: CGRect(origin: .zero, size: titleSize))
                textTransition.setPosition(view: titleView, position: CGPoint(x: availableSize.width / 2.0, y: contentY + titleHeight / 2.0))
                textTransition.setScale(view: titleView, scale: titleScale)
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    subtitleView.accessibilityElementsHidden = true
                    subtitleView.alpha = 0.0
                    self.addSubview(subtitleView)
                }
                if component.subtitle != nil {
                    // Lay out the hidden line before fading it in.
                    let layoutTransition: ComponentTransition = subtitleView.alpha == 0.0 ? .immediate : textTransition
                    layoutTransition.setBounds(view: subtitleView, bounds: CGRect(origin: .zero, size: subtitleSize))
                    layoutTransition.setPosition(view: subtitleView, position: CGPoint(x: availableSize.width / 2.0, y: contentY + titleHeight + spacing + subtitleHeight / 2.0))
                    layoutTransition.setScale(view: subtitleView, scale: subtitleScale)
                }
                textTransition.setAlpha(view: subtitleView, alpha: component.subtitle == nil ? 0.0 : 1.0)
            }

            // Keep the outer button content frame stable while its lines animate inside it.
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
