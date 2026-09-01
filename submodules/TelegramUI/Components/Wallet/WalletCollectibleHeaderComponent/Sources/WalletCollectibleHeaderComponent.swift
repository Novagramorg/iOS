import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import BundleIconComponent
import MultilineTextComponent
import LottieComponent
import WalletCollectibleImageComponent

private let walletCollectibleLottieHosts: Set<String> = [
    "nft.fragment.com",
]

public func walletCollectibleFragmentUrl(_ value: String?) -> String? {
    guard let value,
          let components = URLComponents(string: value),
          components.scheme?.lowercased() == "https",
          components.host?.lowercased() == "fragment.com",
          let url = components.url else {
        return nil
    }
    return url.absoluteString
}

private final class WalletRemoteLottieContent: LottieComponent.Content {
    private static let maximumSize = 5 * 1024 * 1024

    let url: URL

    override var frameRange: Range<Double> {
        return 0.0 ..< 1.0
    }

    init?(urlString: String) {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              walletCollectibleLottieHosts.contains(host) else {
            return nil
        }
        self.url = url
        super.init()
    }

    override func isEqual(to other: LottieComponent.Content) -> Bool {
        guard let other = other as? WalletRemoteLottieContent else {
            return false
        }
        return self.url == other.url
    }

    override func load(_ f: @escaping (LottieComponent.ContentData) -> Void) -> Disposable {
        var request = URLRequest(url: self.url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let response = response as? HTTPURLResponse,
                  (200 ..< 300).contains(response.statusCode),
                  response.expectedContentLength <= 0
                    || response.expectedContentLength <= Int64(Self.maximumSize),
                  let data,
                  data.count <= Self.maximumSize,
                  (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else {
                return
            }
            f(.animation(data: data, cacheKey: self.url.absoluteString))
        }
        task.resume()
        return ActionDisposable {
            task.cancel()
        }
    }
}

public final class WalletCollectibleHeaderComponent: Component {
    public typealias EnvironmentType = Empty

    public struct Item: Equatable {
        public let name: String
        public let imageUrl: String?
        public let lottieUrl: String?
        public let collectionName: String?
        public let collectionUrl: String?

        public init(
            name: String,
            imageUrl: String?,
            lottieUrl: String?,
            collectionName: String?,
            collectionUrl: String?
        ) {
            self.name = name
            self.imageUrl = imageUrl
            self.lottieUrl = lottieUrl
            self.collectionName = collectionName
            self.collectionUrl = collectionUrl
        }
    }

    public let context: AccountContext
    public let theme: PresentationTheme
    public let item: Item
    public let displaysCollection: Bool
    public let openCollection: (String) -> Void

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        item: Item,
        displaysCollection: Bool = true,
        openCollection: @escaping (String) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.item = item
        self.displaysCollection = displaysCollection
        self.openCollection = openCollection
    }

    public static func ==(lhs: WalletCollectibleHeaderComponent, rhs: WalletCollectibleHeaderComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.theme === rhs.theme
            && lhs.item == rhs.item
            && lhs.displaysCollection == rhs.displaysCollection
    }

    public final class View: UIView {
        private let image = ComponentView<Empty>()
        private let lottie = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let collection = ComponentView<Empty>()

        public override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func lottieTapped() {
            (self.lottie.view as? LottieComponent.View)?.playOnce()
        }

        public func setAnimationVisible(_ value: Bool) {
            (self.lottie.view as? LottieComponent.View)?.externalShouldPlay = value
        }

        fileprivate func update(
            component: WalletCollectibleHeaderComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let mediaSide = min(164.0, max(0.0, availableSize.width - 64.0))
            let mediaSize = CGSize(width: mediaSide, height: mediaSide)
            let mediaFrame = CGRect(
                x: floorToScreenPixels((availableSize.width - mediaSide) / 2.0),
                y: 0.0,
                width: mediaSide,
                height: mediaSide
            )
            let mediaCornerRadius: CGFloat = 16.0
            let _ = self.image.update(
                transition: transition,
                component: AnyComponent(WalletCollectibleImageComponent(
                    context: component.context,
                    imageUrl: component.item.imageUrl,
                    placeholderColor: component.theme.list.mediaPlaceholderColor,
                    cornerRadius: mediaCornerRadius
                )),
                environment: {},
                containerSize: mediaSize
            )
            if let imageView = self.image.view {
                if imageView.superview == nil {
                    imageView.isUserInteractionEnabled = false
                    self.addSubview(imageView)
                }
                transition.setFrame(view: imageView, frame: mediaFrame)
            }

            if let lottieUrl = component.item.lottieUrl,
               let lottieContent = WalletRemoteLottieContent(urlString: lottieUrl) {
                let lottieSize = self.lottie.update(
                    transition: transition,
                    component: AnyComponent(LottieComponent(
                        content: lottieContent,
                        startingPosition: .begin,
                        size: mediaSize,
                        loop: false
                    )),
                    environment: {},
                    containerSize: mediaSize
                )
                if let lottieView = self.lottie.view as? LottieComponent.View {
                    if lottieView.superview == nil {
                        lottieView.isUserInteractionEnabled = true
                        lottieView.addGestureRecognizer(UITapGestureRecognizer(
                            target: self,
                            action: #selector(self.lottieTapped)
                        ))
                        self.addSubview(lottieView)
                        lottieView.playOnce()
                    }
                    lottieView.clipsToBounds = true
                    lottieView.layer.cornerRadius = mediaCornerRadius
                    transition.setFrame(view: lottieView, frame: CGRect(origin: mediaFrame.origin, size: lottieSize))
                    transition.setAlpha(view: lottieView, alpha: 1.0)
                }
                self.setAnimationVisible(true)
            } else if let lottieView = self.lottie.view {
                self.setAnimationVisible(false)
                transition.setAlpha(view: lottieView, alpha: 0.0)
            }

            var contentHeight = mediaSize.height + 18.0
            let textWidth = max(0.0, availableSize.width - 48.0)
            let titleText = NSMutableAttributedString(attributedString: NSAttributedString(
                string: component.item.name,
                font: Font.semibold(20.0),
                textColor: component.theme.actionSheet.primaryTextColor
            ))
            if let numberRange = component.item.name.range(of: "#[0-9]+$", options: .regularExpression) {
                titleText.addAttribute(
                    .foregroundColor,
                    value: component.theme.actionSheet.secondaryTextColor,
                    range: NSRange(numberRange, in: component.item.name)
                )
            }
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2
                )),
                environment: {},
                containerSize: CGSize(width: textWidth, height: 100.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                    y: contentHeight,
                    width: titleSize.width,
                    height: titleSize.height
                ))
            }
            contentHeight += titleSize.height

            if component.displaysCollection,
               let collectionName = component.item.collectionName,
               !collectionName.isEmpty {
                let collectionUrl = walletCollectibleFragmentUrl(component.item.collectionUrl)
                var collectionItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: collectionName,
                            font: Font.regular(15.0),
                            textColor: component.theme.actionSheet.secondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )))
                ]
                if collectionUrl != nil {
                    collectionItems.append(AnyComponentWithIdentity(
                        id: "disclosure",
                        component: AnyComponent(BundleIconComponent(
                            name: "Wallet/Chevron",
                            tintColor: component.theme.actionSheet.secondaryTextColor
                        ))
                    ))
                }
                let collectionContent: AnyComponent<Empty> = AnyComponent(HStack(collectionItems, spacing: 4.0))
                let collectionComponent: AnyComponent<Empty>
                if let collectionUrl {
                    collectionComponent = AnyComponent(Button(
                        content: collectionContent,
                        action: {
                            component.openCollection(collectionUrl)
                        }
                    ))
                } else {
                    collectionComponent = collectionContent
                }
                let collectionSize = self.collection.update(
                    transition: transition,
                    component: collectionComponent,
                    environment: {},
                    containerSize: CGSize(width: textWidth, height: 40.0)
                )
                contentHeight += 6.0
                if let collectionView = self.collection.view {
                    if collectionView.superview == nil {
                        self.addSubview(collectionView)
                    }
                    transition.setFrame(view: collectionView, frame: CGRect(
                        x: floorToScreenPixels((availableSize.width - collectionSize.width) / 2.0),
                        y: contentHeight,
                        width: collectionSize.width,
                        height: collectionSize.height
                    ))
                    transition.setAlpha(view: collectionView, alpha: 1.0)
                }
                contentHeight += collectionSize.height
            } else if let collectionView = self.collection.view {
                transition.setAlpha(view: collectionView, alpha: 0.0)
            }

            return CGSize(width: availableSize.width, height: contentHeight)
        }

        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if let result,
               let lottieView = self.lottie.view,
               result === lottieView || result.isDescendant(of: lottieView) {
                return result
            }
            if let result,
               let collectionView = self.collection.view,
               result === collectionView || result.isDescendant(of: collectionView) {
                return result
            }
            return nil
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
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
