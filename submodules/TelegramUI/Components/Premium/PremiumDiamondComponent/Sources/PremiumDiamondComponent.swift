import UIKit
import Display
import ComponentFlow
import MetalEngine
import SwiftSignalKit
import TelegramPresentationData

public final class PremiumDiamondComponent: Component {
    let theme: PresentationTheme

    public init(theme: PresentationTheme) {
        self.theme = theme
    }

    public static func ==(lhs: PremiumDiamondComponent, rhs: PremiumDiamondComponent) -> Bool {
        return lhs.theme === rhs.theme
    }

    public final class View: UIView, ComponentTaggedView {
        public final class Tag {
            public init() {
            }
        }

        private let diamondLayer = InteractiveDiamondLayer()
        private let readyPromise = Promise<Bool>()

        public var ready: Signal<Bool, NoError> {
            return self.readyPromise.get()
        }

        public func matches(tag: Any) -> Bool {
            return tag is Tag
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isOpaque = false
            self.diamondLayer.onReady = { [weak self] in
                self?.readyPromise.set(.single(true))
            }
            self.layer.addSublayer(self.diamondLayer)

            let panGesture = UIPanGestureRecognizer(target: self.diamondLayer, action: #selector(InteractiveDiamondLayer.handlePan(_:)))
            self.addGestureRecognizer(panGesture)
            let tapGesture = UITapGestureRecognizer(target: self.diamondLayer, action: #selector(InteractiveDiamondLayer.handleTap(_:)))
            tapGesture.require(toFail: panGesture)
            self.addGestureRecognizer(tapGesture)
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: PremiumDiamondComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.diamondLayer.bounds = CGRect(origin: .zero, size: availableSize)
            self.diamondLayer.position = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5 - 8.0)
            self.diamondLayer.lightBackground = !component.theme.overallDarkAppearance
            self.diamondLayer.setNeedsUpdate()
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
