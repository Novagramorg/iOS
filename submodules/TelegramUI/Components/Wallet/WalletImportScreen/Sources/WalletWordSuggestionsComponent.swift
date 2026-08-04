import Foundation
import UIKit
import Display
import ComponentFlow

final class WalletWordSuggestionsComponent: Component {
    typealias EnvironmentType = Empty

    static let height: CGFloat = 44.0
    static let notchHeight: CGFloat = 7.5

    let fieldIndex: Int
    let query: String
    let words: [String]
    let action: (String) -> Void

    init(fieldIndex: Int, query: String, words: [String], action: @escaping (String) -> Void) {
        self.fieldIndex = fieldIndex
        self.query = query
        self.words = Array(words.prefix(3))
        self.action = action
    }

    static func ==(lhs: WalletWordSuggestionsComponent, rhs: WalletWordSuggestionsComponent) -> Bool {
        return lhs.fieldIndex == rhs.fieldIndex
            && lhs.query == rhs.query
            && lhs.words == rhs.words
    }

    final class View: UIView, UIScrollViewDelegate {
        private final class ItemButton: UIButton {
            var restingBackgroundColor: UIColor = .clear {
                didSet {
                    self.updateBackgroundColor()
                }
            }

            override var isHighlighted: Bool {
                didSet {
                    self.updateBackgroundColor()
                }
            }

            private func updateBackgroundColor() {
                self.backgroundColor = self.isHighlighted
                    ? UIColor(rgb: 0x5a5a5e)
                    : self.restingBackgroundColor
            }
        }

        private static let itemFont = Font.semibold(14.0)

        private let blurView: BlurredBackgroundView
        private let backgroundLayer = SimpleShapeLayer()
        private let shadowLayer = SimpleLayer()
        private let scrollView = UIScrollView()
        private var itemButtons: [ItemButton] = []
        private var separatorViews: [UIView] = []

        private var component: WalletWordSuggestionsComponent?
        private var relativeNotchPositionX: CGFloat?

        override init(frame: CGRect) {
            let backgroundColor = UIColor(rgb: 0x2c2c2e).withAlphaComponent(0.92)
            self.blurView = BlurredBackgroundView(color: backgroundColor, enableBlur: true)

            super.init(frame: frame)
            
            self.layer.allowsGroupOpacity = true

            self.disablesInteractiveTransitionGestureRecognizer = true
            self.disablesInteractiveKeyboardGestureRecognizer = true

            self.shadowLayer.shadowColor = UIColor.black.cgColor
            self.shadowLayer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.shadowLayer.shadowRadius = 15.0
            self.shadowLayer.shadowOpacity = 0.2

            self.backgroundLayer.fillColor = backgroundColor.cgColor
            self.blurView.layer.mask = self.backgroundLayer

            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceVertical = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.layer.cornerRadius = 16.0
            self.scrollView.layer.masksToBounds = true
            if #available(iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }

            self.layer.addSublayer(self.shadowLayer)
            self.addSubview(self.blurView)
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func adjustBackground(relativePositionX: CGFloat) {
            self.relativeNotchPositionX = relativePositionX
            self.updateBackground(size: self.bounds.size, relativePositionX: relativePositionX)
        }

        private func updateBackground(size: CGSize, relativePositionX: CGFloat) {
            guard size.width > 0.0, size.height > 0.0 else {
                return
            }

            let bodyMinY = WalletWordSuggestionsComponent.notchHeight
            let radius: CGFloat = 16.0
            let notchWidth: CGFloat = 19.0
            let notchBaseX = min(
                size.width - radius - notchWidth,
                max(radius, floor(relativePositionX - notchWidth / 2.0))
            )

            let path = CGMutablePath()
            path.move(to: CGPoint(x: radius, y: bodyMinY))
            path.addLine(to: CGPoint(x: notchBaseX, y: bodyMinY))
            path.addCurve(
                to: CGPoint(x: notchBaseX + 7.49968, y: bodyMinY - 5.32576),
                control1: CGPoint(x: notchBaseX + 2.10085, y: bodyMinY),
                control2: CGPoint(x: notchBaseX + 5.41005, y: bodyMinY - 3.11103)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + 8.95665, y: bodyMinY - 6.61485),
                control1: CGPoint(x: notchBaseX + 8.2352, y: bodyMinY - 6.10531),
                control2: CGPoint(x: notchBaseX + 8.60297, y: bodyMinY - 6.49509)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + 9.91544, y: bodyMinY - 6.61599),
                control1: CGPoint(x: notchBaseX + 9.29432, y: bodyMinY - 6.72919),
                control2: CGPoint(x: notchBaseX + 9.5775, y: bodyMinY - 6.72953)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + 11.3772, y: bodyMinY - 5.32853),
                control1: CGPoint(x: notchBaseX + 10.2694, y: bodyMinY - 6.49707),
                control2: CGPoint(x: notchBaseX + 10.6387, y: bodyMinY - 6.10756)
            )
            path.addCurve(
                to: CGPoint(x: notchBaseX + notchWidth, y: bodyMinY),
                control1: CGPoint(x: notchBaseX + 13.477, y: bodyMinY - 3.11363),
                control2: CGPoint(x: notchBaseX + 16.817, y: bodyMinY)
            )
            path.addLine(to: CGPoint(x: size.width - radius, y: bodyMinY))
            path.addArc(
                tangent1End: CGPoint(x: size.width, y: bodyMinY),
                tangent2End: CGPoint(x: size.width, y: bodyMinY + radius),
                radius: radius
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height - radius))
            path.addArc(
                tangent1End: CGPoint(x: size.width, y: size.height),
                tangent2End: CGPoint(x: size.width - radius, y: size.height),
                radius: radius
            )
            path.addLine(to: CGPoint(x: radius, y: size.height))
            path.addArc(
                tangent1End: CGPoint(x: 0.0, y: size.height),
                tangent2End: CGPoint(x: 0.0, y: size.height - radius),
                radius: radius
            )
            path.addLine(to: CGPoint(x: 0.0, y: bodyMinY + radius))
            path.addArc(
                tangent1End: CGPoint(x: 0.0, y: bodyMinY),
                tangent2End: CGPoint(x: radius, y: bodyMinY),
                radius: radius
            )
            path.closeSubpath()

            self.shadowLayer.frame = CGRect(origin: .zero, size: size)
            self.shadowLayer.shadowPath = path
            self.blurView.frame = CGRect(origin: .zero, size: size)
            self.blurView.update(size: size, transition: .immediate)
            self.backgroundLayer.frame = CGRect(origin: .zero, size: size)
            self.backgroundLayer.path = path
        }

        @objc private func itemPressed(_ sender: UIButton) {
            guard let component = self.component, component.words.indices.contains(sender.tag) else {
                return
            }
            component.action(component.words[sender.tag])
        }

        func update(
            component: WalletWordSuggestionsComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let resetScrollingPosition = self.component?.words != component.words
            self.component = component

            while self.itemButtons.count < component.words.count {
                let button = ItemButton(type: .custom)
                button.titleLabel?.font = Self.itemFont
                button.addTarget(self, action: #selector(self.itemPressed(_:)), for: .touchUpInside)
                self.itemButtons.append(button)
                self.scrollView.addSubview(button)
            }
            while self.itemButtons.count > component.words.count {
                self.itemButtons.removeLast().removeFromSuperview()
            }

            let separatorCount = max(0, component.words.count - 1)
            while self.separatorViews.count < separatorCount {
                let separatorView = UIView()
                separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
                separatorView.isUserInteractionEnabled = false
                self.separatorViews.append(separatorView)
                self.scrollView.addSubview(separatorView)
            }
            while self.separatorViews.count > separatorCount {
                self.separatorViews.removeLast().removeFromSuperview()
            }

            var itemWidths: [CGFloat] = []
            var contentWidth: CGFloat = 0.0
            for word in component.words {
                let textWidth = ceil((word as NSString).size(withAttributes: [.font: Self.itemFont]).width)
                let itemWidth = max(64.0, textWidth + 32.0)
                itemWidths.append(itemWidth)
                contentWidth += itemWidth
            }

            let width = min(availableSize.width, contentWidth)
            let size = CGSize(width: width, height: WalletWordSuggestionsComponent.height)
            let bodyHeight = WalletWordSuggestionsComponent.height - WalletWordSuggestionsComponent.notchHeight
            self.scrollView.frame = CGRect(
                x: 0.0,
                y: WalletWordSuggestionsComponent.notchHeight,
                width: width,
                height: bodyHeight
            )
            self.scrollView.contentSize = CGSize(width: contentWidth, height: bodyHeight)
            self.scrollView.alwaysBounceHorizontal = contentWidth > width
            if resetScrollingPosition {
                self.scrollView.contentOffset = .zero
            }

            var itemX: CGFloat = 0.0
            for index in component.words.indices {
                let button = self.itemButtons[index]
                let word = component.words[index]
                let title = NSMutableAttributedString(
                    string: word,
                    attributes: [
                        .font: Self.itemFont,
                        .foregroundColor: UIColor.white
                    ]
                )
                let queryLength = min((component.query as NSString).length, title.length)
                if queryLength > 0 {
                    title.addAttribute(
                        .foregroundColor,
                        value: UIColor(rgb: 0xb9b9ba),
                        range: NSRange(location: 0, length: queryLength)
                    )
                }
                button.tag = index
                button.setAttributedTitle(title, for: .normal)
                button.setAttributedTitle(title, for: .highlighted)
                button.restingBackgroundColor = index == 0 ? UIColor(rgb: 0xffffff, alpha: 0.1) : .clear
                button.frame = CGRect(x: itemX, y: 0.0, width: itemWidths[index], height: bodyHeight)
                button.accessibilityLabel = word
                var accessibilityTraits: UIAccessibilityTraits = .button
                if index == 0 {
                    accessibilityTraits.insert(.selected)
                }
                button.accessibilityTraits = accessibilityTraits

                itemX += itemWidths[index]
                if index < self.separatorViews.count {
                    self.separatorViews[index].frame = CGRect(
                        x: itemX - UIScreenPixel,
                        y: 0.0,
                        width: UIScreenPixel,
                        height: bodyHeight
                    )
                }
            }

            let relativeNotchPositionX = self.relativeNotchPositionX ?? width / 2.0
            self.updateBackground(size: size, relativePositionX: relativeNotchPositionX)

            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}
