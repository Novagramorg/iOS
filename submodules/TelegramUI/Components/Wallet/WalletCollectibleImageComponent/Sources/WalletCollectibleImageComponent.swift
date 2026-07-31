import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import ComponentFlow
import PhotoResources
import TextFormat

public final class WalletCollectibleImageComponent: Component {
    public let context: AccountContext
    public let imageUrl: String?
    public let placeholderColor: UIColor
    public let cornerRadius: CGFloat

    public init(
        context: AccountContext,
        imageUrl: String?,
        placeholderColor: UIColor,
        cornerRadius: CGFloat
    ) {
        self.context = context
        self.imageUrl = imageUrl
        self.placeholderColor = placeholderColor
        self.cornerRadius = cornerRadius
    }

    public static func ==(lhs: WalletCollectibleImageComponent, rhs: WalletCollectibleImageComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.imageUrl == rhs.imageUrl
            && lhs.placeholderColor == rhs.placeholderColor
            && lhs.cornerRadius == rhs.cornerRadius
    }

    public final class View: UIView {
        private let placeholder = ComponentView<Empty>()
        private let imageNode = TransformImageNode()
        private let fetchDisposable = MetaDisposable()

        private weak var accountContext: AccountContext?
        private var imageUrl: String?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
            self.imageNode.isUserInteractionEnabled = false
            self.imageNode.isHidden = true
            self.addSubview(self.imageNode.view)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.fetchDisposable.dispose()
        }

        func update(
            component: WalletCollectibleImageComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let _ = self.placeholder.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: component.placeholderColor,
                    cornerRadius: component.cornerRadius
                )),
                environment: {},
                containerSize: availableSize
            )
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, belowSubview: self.imageNode.view)
                }
                transition.setFrame(
                    view: placeholderView,
                    frame: CGRect(origin: .zero, size: availableSize)
                )
            }

            transition.setFrame(
                view: self.imageNode.view,
                frame: CGRect(origin: .zero, size: availableSize)
            )
            self.imageNode.asyncLayout()(TransformImageArguments(
                corners: ImageCorners(radius: component.cornerRadius),
                imageSize: availableSize,
                boundingSize: availableSize,
                intrinsicInsets: UIEdgeInsets(),
                emptyColor: component.placeholderColor
            ))()

            if self.accountContext !== component.context || self.imageUrl != component.imageUrl {
                self.accountContext = component.context
                self.imageUrl = component.imageUrl
                self.fetchDisposable.set(nil)
                self.imageNode.reset()

                if let imageUrl = component.imageUrl, !imageUrl.isEmpty {
                    let image = TelegramMediaWebFile(
                        resource: HttpReferenceMediaResource(url: imageUrl, size: nil),
                        mimeType: "image/jpeg",
                        size: 0,
                        attributes: []
                    )
                    self.imageNode.isHidden = false
                    self.imageNode.setSignal(chatWebFileImage(account: component.context.account, file: image))
                    self.fetchDisposable.set(chatMessageWebFileInteractiveFetched(
                        account: component.context.account,
                        userLocation: .other,
                        image: image
                    ).startStrict())
                } else {
                    self.imageNode.isHidden = true
                }
            }

            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            transition: transition
        )
    }
}
