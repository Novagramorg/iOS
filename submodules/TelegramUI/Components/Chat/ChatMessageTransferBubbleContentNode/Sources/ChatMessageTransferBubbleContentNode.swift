import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TextFormat
import LocalizedPeerData
import TelegramStringFormatting
import WallpaperBackgroundNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import WalletContext

public final class ChatMessageTransferBubbleContentNode: ChatMessageBubbleContentNode {
    private let labelNode: TextNode
    private var labelBackgroundNode: WallpaperBubbleBackgroundNode?
    private let labelBackgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?

    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let cardNode: ASDisplayNode
    private let cardBackgroundNode: ASImageNode
    private let cardIconNode: ASImageNode
    private let amountNode: TextNode
    private let nameNode: TextNode
    private let addressNode: TextNode
    private let captionNode: TextNode
    private let ribbonBackgroundNode: ASImageNode
    private let ribbonTextNode: TextNode

    private var cachedLabelBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?

    override public var disablesClipping: Bool {
        return true
    }

    required public init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.labelBackgroundMaskNode = ASImageNode()
        self.labelBackgroundMaskNode.displaysAsynchronously = false

        self.cardNode = ASDisplayNode()
        self.cardNode.isUserInteractionEnabled = false
        self.cardNode.clipsToBounds = true
        self.cardNode.cornerRadius = 20.0

        self.cardBackgroundNode = ASImageNode()
        self.cardBackgroundNode.displaysAsynchronously = false
        self.cardBackgroundNode.displayWithoutProcessing = true
        self.cardBackgroundNode.contentMode = .scaleAspectFill
        self.cardBackgroundNode.image = UIImage(bundleImageName: "Wallet/CardChatMock")

        self.cardIconNode = ASImageNode()
        self.cardIconNode.displaysAsynchronously = false
        self.cardIconNode.displayWithoutProcessing = true
        self.cardIconNode.contentMode = .scaleAspectFit
        self.cardIconNode.image = UIImage(bundleImageName: "Wallet/CardGram")

        self.amountNode = TextNode()
        self.amountNode.isUserInteractionEnabled = false
        self.amountNode.displaysAsynchronously = false

        self.nameNode = TextNode()
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.displaysAsynchronously = false

        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        self.addressNode.displaysAsynchronously = false

        self.captionNode = TextNode()
        self.captionNode.isUserInteractionEnabled = false
        self.captionNode.displaysAsynchronously = false

        self.ribbonBackgroundNode = ASImageNode()
        self.ribbonBackgroundNode.displaysAsynchronously = false
        self.ribbonBackgroundNode.displayWithoutProcessing = true

        self.ribbonTextNode = TextNode()
        self.ribbonTextNode.isUserInteractionEnabled = false
        self.ribbonTextNode.displaysAsynchronously = false

        super.init()

        self.cardNode.addSubnode(self.cardBackgroundNode)
        self.cardNode.addSubnode(self.cardIconNode)
        self.cardNode.addSubnode(self.amountNode)
        self.cardNode.addSubnode(self.nameNode)
        self.cardNode.addSubnode(self.addressNode)

        self.addSubnode(self.cardNode)
        self.addSubnode(self.ribbonBackgroundNode)
        self.addSubnode(self.ribbonTextNode)
        self.addSubnode(self.captionNode)
        self.addSubnode(self.labelNode)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeAmountLayout = TextNode.asyncLayout(self.amountNode)
        let makeNameLayout = TextNode.asyncLayout(self.nameNode)
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        let makeCaptionLayout = TextNode.asyncLayout(self.captionNode)
        let makeRibbonTextLayout = TextNode.asyncLayout(self.ribbonTextNode)
        let cachedLabelBackgroundImage = self.cachedLabelBackgroundImage

        return { item, _, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(
                hidesSimpleAuthorHeader: true,
                headerSpacing: 0.0,
                hidesBackground: .always,
                forceFullCorners: false,
                forceAlignment: .center
            )

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, _ in
                let engineMessage = EngineMessage(item.message)
                guard let transfer = walletTransferMessageData(
                    message: engineMessage,
                    accountPeerId: item.context.account.peerId
                ) else {
                    return (0.0, { _ in
                        return (CGSize(), { _, _, _ in })
                    })
                }

                let tonUsdRate = item.context.currentAppConfiguration.with { configuration -> Double? in
                    return configuration.data?["ton_usd_rate"] as? Double
                }
                let serviceText = walletTransferServiceMessageString(
                    presentationData: (item.presentationData.theme.theme, item.presentationData.theme.wallpaper),
                    strings: item.presentationData.strings,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    message: engineMessage,
                    transfer: transfer,
                    tonUsdRate: tonUsdRate
                )

                let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(
                    attributedString: serviceText,
                    backgroundColor: nil,
                    maximumNumberOfLines: 0,
                    truncationType: .end,
                    constrainedSize: CGSize(width: max(1.0, constrainedSize.width - 32.0), height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let cardSize = CGSize(width: 216.0, height: 148.0)

                let amountFont = Font.with(
                    size: 18.0,
                    design: .round,
                    weight: .bold,
                    traits: .monospacedNumbers
                )
                let fractionalAmountFont = Font.with(
                    size: 14.0,
                    design: .round,
                    weight: .bold,
                    traits: .monospacedNumbers
                )
                let sign: String
                switch transfer.direction {
                case .incoming:
                    sign = "+"
                case .outgoing:
                    sign = "−"
                }
                let formattedAmount = sign + formatTonAmountText(
                    transfer.amount,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    maxDecimalPositions: 3
                )
                let amountText = NSMutableAttributedString(attributedString: tonAmountAttributedString(
                    formattedAmount,
                    integralFont: amountFont,
                    fractionalFont: fractionalAmountFont,
                    color: .white,
                    decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator
                ))
                //TODO:localize
                let currencyTitle = " Grams"
                amountText.append(NSAttributedString(
                    string: currencyTitle,
                    font: amountFont,
                    textColor: UIColor(rgb: 0x0fddff)
                ))
                let (amountLayout, amountApply) = makeAmountLayout(TextNodeLayoutArguments(
                    attributedString: amountText,
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 24.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let peerName = item.message.peers[item.message.id.peerId].flatMap(EnginePeer.init)?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder).uppercased() ?? ""
                let (nameLayout, nameApply) = makeNameLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: peerName,
                        font: Font.with(size: 12.0, design: .monospace, weight: .semibold),
                        textColor: UIColor(rgb: 0x0bdbff),
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 30.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let (addressLayout, addressApply) = makeAddressLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: transfer.peerAddress.isEmpty ? "" : formatTonAddress(transfer.peerAddress),
                        font: Font.with(size: 10.0, design: .monospace, weight: .medium),
                        textColor: UIColor(rgb: 0x005fdb),
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 2,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 24.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    lineSpacing: 0.05,
                    cutout: nil,
                    insets: UIEdgeInsets(),
                    textShadowColor: UIColor(rgb: 0x138cfe),
                    textShadowBlur: 0.0
                ))

                let hasCaption = !transfer.caption.isEmpty
                let (captionLayout, captionApply) = makeCaptionLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: transfer.caption,
                        font: Font.regular(13.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 0,
                    truncationType: .end,
                    constrainedSize: CGSize(width: max(1.0, cardSize.width - 24.0), height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let ribbonTitle: String
                let ribbonColor: UIColor
                switch transfer.direction {
                case .incoming:
                    //TODO:localize
                    ribbonTitle = "received"
                    ribbonColor = UIColor(rgb: 0x0075f6)
                case .outgoing:
                    //TODO:localize
                    ribbonTitle = "sent"
                    ribbonColor = UIColor(rgb: 0x5ec2ff)
                }
                let (ribbonTextLayout, ribbonTextApply) = makeRibbonTextLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: ribbonTitle,
                        font: Font.semibold(11.0),
                        textColor: .white,
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 1,
                    truncationType: .end,
                    constrainedSize: CGSize(width: 80.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                var labelRects = labelLayout.linesRects()
                if labelRects.count > 1 {
                    let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                    for index in sortedIndices {
                        for offset in -1 ... 1 where offset != 0 {
                            let adjacentIndex = index + offset
                            if adjacentIndex >= 0 && adjacentIndex < labelRects.count && abs(labelRects[adjacentIndex].width - labelRects[index].width) < 40.0 {
                                let width = max(labelRects[adjacentIndex].width, labelRects[index].width)
                                labelRects[adjacentIndex].size.width = width
                                labelRects[index].size.width = width
                            }
                        }
                    }
                }
                for index in labelRects.indices {
                    labelRects[index] = labelRects[index].insetBy(dx: -7.0, dy: floor((labelRects[index].height - 22.0) / 2.0))
                    labelRects[index].size.height = 22.0
                    labelRects[index].origin.x = floor((labelLayout.size.width - labelRects[index].width) / 2.0)
                }

                let labelBackgroundImage: (CGPoint, UIImage)?
                var labelBackgroundUpdated = false
                if let (currentOffset, currentImage, currentRects) = cachedLabelBackgroundImage, currentRects == labelRects {
                    labelBackgroundImage = (currentOffset, currentImage)
                } else {
                    labelBackgroundImage = LinkHighlightingNode.generateImage(
                        color: .black,
                        inset: 0.0,
                        innerRadius: 11.0,
                        outerRadius: 11.0,
                        rects: labelRects,
                        useModernPathCalculation: false
                    )
                    labelBackgroundUpdated = true
                }

                let outerInset: CGFloat = 4.0
                let captionSpacing = hasCaption ? 7.0 : 0.0
                let captionBottomInset = hasCaption ? 4.0 : 0.0
                let mediaSize = CGSize(
                    width: cardSize.width + outerInset * 2.0,
                    height: cardSize.height + outerInset * 2.0 + captionSpacing + (hasCaption ? captionLayout.size.height : 0.0) + captionBottomInset
                )
                let totalSize = CGSize(
                    width: max(mediaSize.width, labelLayout.size.width),
                    height: labelLayout.size.height + 13.0 + mediaSize.height
                )

                return (totalSize.width, { boundingWidth in
                    return (totalSize, { [weak self] animation, _, _ in
                        guard let self else {
                            return
                        }
                        self.item = item

                        let _ = labelApply()
                        let _ = amountApply()
                        let _ = nameApply()
                        let _ = addressApply()
                        let _ = captionApply()
                        let _ = ribbonTextApply()

                        let labelFrame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((boundingWidth - labelLayout.size.width) * 0.5), y: 2.0),
                            size: labelLayout.size
                        )
                        self.labelNode.frame = labelFrame

                        let mediaFrame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((boundingWidth - mediaSize.width) * 0.5), y: labelLayout.size.height + 13.0),
                            size: mediaSize
                        )
                        let cardFrame = CGRect(
                            origin: CGPoint(x: mediaFrame.minX + outerInset, y: mediaFrame.minY + outerInset),
                            size: cardSize
                        )
                        animation.animator.updateFrame(layer: self.cardNode.layer, frame: cardFrame, completion: nil)
                        self.cardBackgroundNode.frame = CGRect(origin: .zero, size: cardSize)

                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        self.cardIconNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - iconSize.width) * 0.5), y: 20.0),
                            size: iconSize
                        )
                        self.amountNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - amountLayout.size.width) * 0.5), y: 61.0),
                            size: amountLayout.size
                        )
                        self.nameNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - nameLayout.size.width) * 0.5), y: 97.0),
                            size: nameLayout.size
                        )
                        self.addressNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - addressLayout.size.width) * 0.5), y: 114.0),
                            size: addressLayout.size
                        )

                        let ribbonSize = CGSize(width: 68.0, height: 68.0)
                        let ribbonFrame = CGRect(
                            origin: CGPoint(x: cardFrame.maxX - ribbonSize.width + 2.0, y: cardFrame.minY - 2.0),
                            size: ribbonSize
                        )
                        self.ribbonBackgroundNode.image = generateTintedImage(
                            image: UIImage(bundleImageName: "Chat/Message/GiftRibbon"),
                            color: ribbonColor
                        )
                        self.ribbonBackgroundNode.frame = ribbonFrame
                        self.ribbonTextNode.transform = CATransform3DMakeRotation(.pi / 4.0, 0.0, 0.0, 1.0)
                        self.ribbonTextNode.bounds = CGRect(origin: .zero, size: ribbonTextLayout.size)
                        self.ribbonTextNode.position = ribbonFrame.center.offsetBy(dx: 7.0, dy: -6.0)

                        self.captionNode.isHidden = !hasCaption
                        if hasCaption {
                            self.captionNode.frame = CGRect(
                                origin: CGPoint(
                                    x: mediaFrame.minX + floorToScreenPixels((mediaFrame.width - captionLayout.size.width) * 0.5),
                                    y: cardFrame.maxY + captionSpacing
                                ),
                                size: captionLayout.size
                            )
                        } else {
                            self.captionNode.frame = CGRect()
                        }

                        if self.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true
                            backgroundContent.cornerRadius = 24.0
                            self.mediaBackgroundContent = backgroundContent
                            self.insertSubnode(backgroundContent, at: 0)
                        }
                        if let mediaBackgroundContent = self.mediaBackgroundContent {
                            animation.animator.updateFrame(layer: mediaBackgroundContent.layer, frame: mediaFrame, completion: nil)
                            mediaBackgroundContent.cornerRadius = 24.0
                        }

                        let baseLabelBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                        if let (offset, image) = labelBackgroundImage {
                            if self.labelBackgroundNode == nil, let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                self.labelBackgroundNode = backgroundNode
                                self.insertSubnode(backgroundNode, at: 0)
                            }
                            if labelBackgroundUpdated, let labelBackgroundNode = self.labelBackgroundNode {
                                if labelRects.count == 1 {
                                    labelBackgroundNode.clipsToBounds = true
                                    labelBackgroundNode.cornerRadius = labelRects[0].height * 0.5
                                    labelBackgroundNode.view.mask = nil
                                } else {
                                    labelBackgroundNode.clipsToBounds = false
                                    labelBackgroundNode.cornerRadius = 0.0
                                    labelBackgroundNode.view.mask = self.labelBackgroundMaskNode.view
                                }
                            }
                            if let labelBackgroundNode = self.labelBackgroundNode {
                                animation.animator.updateFrame(
                                    layer: labelBackgroundNode.layer,
                                    frame: CGRect(
                                        origin: CGPoint(x: baseLabelBackgroundFrame.minX + offset.x, y: baseLabelBackgroundFrame.minY + offset.y),
                                        size: image.size
                                    ),
                                    completion: nil
                                )
                            }
                            self.labelBackgroundMaskNode.image = image
                            self.labelBackgroundMaskNode.frame = CGRect(origin: .zero, size: image.size)
                            self.cachedLabelBackgroundImage = (offset, image, labelRects)
                        }

                        if let (rect, size) = self.absoluteRect {
                            self.updateAbsoluteRect(rect, within: size)
                        }
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)

    }

    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }

        var rects: [(CGRect, CGRect)]?
        let textNodeFrame = self.labelNode.frame
        if let point, let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(
            x: point.x - textNodeFrame.minX,
            y: point.y - textNodeFrame.minY - 10.0
        )) {
            let possibleNames = [TelegramTextAttributes.URL, TelegramTextAttributes.PeerMention]
            for name in possibleNames where attributes[NSAttributedString.Key(rawValue: name)] != nil {
                rects = self.labelNode.lineAndAttributeRects(name: name, at: index)
                break
            }
        }

        if let rects {
            let mappedRects = rects.map { lineRect, attributeRect -> CGRect in
                var attributeRect = attributeRect
                attributeRect.origin.x = floor((textNodeFrame.size.width - lineRect.width) * 0.5) + attributeRect.origin.x
                return attributeRect
            }
            let highlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                highlightingNode = current
            } else {
                let serviceColor = serviceMessageColorComponents(
                    theme: item.presentationData.theme.theme,
                    wallpaper: item.presentationData.theme.wallpaper
                )
                highlightingNode = LinkHighlightingNode(color: serviceColor.linkHighlight)
                highlightingNode.inset = 2.5
                self.linkHighlightingNode = highlightingNode
                self.insertSubnode(highlightingNode, belowSubnode: self.labelNode)
            }
            highlightingNode.frame = self.labelNode.frame.offsetBy(dx: 0.0, dy: 1.5)
            highlightingNode.updateRects(mappedRects)
        } else if let highlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            highlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak highlightingNode] _ in
                highlightingNode?.removeFromSupernode()
            })
        }
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if gesture == .tap, let (_, attributes) = self.labelNode.attributesAtPoint(CGPoint(
            x: point.x - self.labelNode.frame.minX,
            y: point.y - self.labelNode.frame.minY - 10.0
        )) {
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                    guard let item = self?.item else {
                        return
                    }
                    let controller = item.context.sharedContext.makeWalletInfoScreen(
                        context: item.context,
                        mode: .gram,
                        completion: nil
                    )
                    if let navigationController = item.controllerInteraction.navigationController() {
                        navigationController.pushViewController(controller)
                    } else {
                        item.controllerInteraction.presentControllerInCurrent(controller, nil)
                    }
                }))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(
                    peerId: peerMention.peerId,
                    mention: peerMention.mention,
                    openProfile: false
                ))
            }
        }

        if self.cardNode.frame.contains(point) || self.captionNode.frame.contains(point) || self.mediaBackgroundContent?.frame.contains(point) == true {
            guard gesture == .tap else {
                return ChatMessageBubbleContentTapAction(content: .openMessage)
            }
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                guard let item = self?.item else {
                    return
                }
                let engineMessage = EngineMessage(item.message)
                guard let transfer = walletTransferMessageData(
                    message: engineMessage,
                    accountPeerId: item.context.account.peerId
                ) else {
                    return
                }

                let direction: WalletContext.Transaction.Direction
                switch transfer.direction {
                case .incoming:
                    direction = .incoming
                case .outgoing:
                    direction = .outgoing
                }

                let comment: String?
                if transfer.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    comment = nil
                } else {
                    comment = transfer.caption
                }
                let walletContext = item.context.walletContext
                let transaction: WalletContext.Transaction
                if let current = walletContext?.stateValue.transactions.items.first(where: { $0.id == transfer.transactionId }) {
                    transaction = current
                } else {
                    let peer: WalletContext.Transaction.Peer
                    if let enginePeer = item.message.peers[item.message.id.peerId].flatMap(EnginePeer.init),
                       enginePeer.id.namespace == Namespaces.Peer.CloudUser {
                        peer = .user(enginePeer, address: transfer.peerAddress, domain: nil)
                    } else if !transfer.peerAddress.isEmpty {
                        peer = .address(transfer.peerAddress, domain: nil)
                    } else {
                        peer = .unsupported
                    }
                    let logicalTime = transfer.transactionId.split(separator: ":", maxSplits: 1).first.map(String.init)
                        ?? transfer.transactionId
                    transaction = WalletContext.Transaction(
                        id: transfer.transactionId,
                        logicalTime: logicalTime,
                        timestamp: item.message.timestamp,
                        direction: direction,
                        amount: transfer.amount,
                        fee: 0,
                        peer: peer,
                        comment: comment
                    )
                }
                let controller: ViewController
                if let walletContext {
                    controller = item.context.sharedContext.makeWalletTransactionScreen(
                        context: item.context,
                        walletContext: walletContext,
                        transaction: transaction
                    )
                } else {
                    controller = item.context.sharedContext.makeWalletTransactionScreen(
                        context: item.context,
                        transaction: transaction
                    )
                }
                if let navigationController = item.controllerInteraction.navigationController() {
                    navigationController.pushViewController(controller)
                } else {
                    item.controllerInteraction.presentControllerInCurrent(controller, nil)
                }
            }))
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}
