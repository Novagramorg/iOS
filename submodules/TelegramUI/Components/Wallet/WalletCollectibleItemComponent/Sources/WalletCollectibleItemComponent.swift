import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import PhotoResources
import AccountContext
import WalletContext

public final class WalletCollectibleItemComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let collectible: WalletContext.Collectible

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        collectible: WalletContext.Collectible
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.collectible = collectible
    }

    public static func ==(lhs: WalletCollectibleItemComponent, rhs: WalletCollectibleItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.collectible != rhs.collectible {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let imagePlaceholderView: UIView
        private let imageNode: TransformImageNode
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let fetchDisposable = MetaDisposable()

        private weak var accountContext: AccountContext?
        private var imageUrl: String?

        override public init(frame: CGRect) {
            self.imagePlaceholderView = UIView()
            self.imageNode = TransformImageNode()

            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.imagePlaceholderView.isUserInteractionEnabled = false
            self.imagePlaceholderView.layer.cornerRadius = 12.0
            self.imagePlaceholderView.clipsToBounds = true
            self.addSubview(self.imagePlaceholderView)

            self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
            self.imageNode.isUserInteractionEnabled = false
            self.imageNode.isHidden = true
            self.addSubview(self.imageNode.view)
        }

        deinit {
            self.fetchDisposable.dispose()
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletCollectibleItemComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let imageSize = CGSize(width: 40.0, height: 40.0)
            self.imagePlaceholderView.backgroundColor = component.theme.list.mediaPlaceholderColor
            transition.setFrame(view: self.imagePlaceholderView, frame: CGRect(origin: CGPoint(x: -4.0, y: 0.0), size: imageSize))
            transition.setFrame(view: self.imageNode.view, frame: CGRect(origin: CGPoint(x: -4.0, y: 0.0), size: imageSize))
            self.imageNode.asyncLayout()(TransformImageArguments(
                corners: ImageCorners(radius: 12.0),
                imageSize: imageSize,
                boundingSize: imageSize,
                intrinsicInsets: UIEdgeInsets(),
                emptyColor: component.theme.list.mediaPlaceholderColor
            ))()

            if self.accountContext !== component.context || self.imageUrl != component.collectible.imageUrl {
                self.accountContext = component.context
                self.imageUrl = component.collectible.imageUrl
                self.fetchDisposable.set(nil)

                if let imageUrl = component.collectible.imageUrl, !imageUrl.isEmpty {
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

            let textOriginX: CGFloat = 46.0
            let textAvailableWidth = max(0.0, availableSize.width - textOriginX)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.collectible.name,
                        font: Font.semibold(17.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )
            let subtitleText: String
            if let receivedAt = component.collectible.receivedAt {
                let dateComponents = getDateTimeComponents(timestamp: receivedAt)
                let date = stringForMediumCompactDate(
                    timestamp: receivedAt,
                    strings: component.strings,
                    dateTimeFormat: component.dateTimeFormat,
                    withTime: false
                )
                let time = stringForShortTimestamp(
                    hours: dateComponents.hour,
                    minutes: dateComponents.minutes,
                    dateTimeFormat: component.dateTimeFormat
                )
                subtitleText = "Received \(component.strings.Time_MediumDate(date, time).string)"
            } else {
                subtitleText = "Received"
            }
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: subtitleText,
                        font: Font.regular(15.0),
                        textColor: component.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )

            let textSpacing: CGFloat = 1.0
            let textHeight = titleSize.height + textSpacing + subtitleSize.height
            let textOriginY = floor((imageSize.height - textHeight) * 0.5)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: textOriginY), size: titleSize)
                )
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(
                    view: subtitleView,
                    frame: CGRect(
                        origin: CGPoint(x: textOriginX, y: textOriginY + titleSize.height + textSpacing),
                        size: subtitleSize
                    )
                )
            }

            return CGSize(width: availableSize.width, height: imageSize.height)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
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
            state: state,
            environment: environment,
            transition: transition
        )
    }
}
