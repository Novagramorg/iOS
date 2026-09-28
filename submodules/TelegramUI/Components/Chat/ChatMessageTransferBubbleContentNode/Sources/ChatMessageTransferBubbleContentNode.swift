import Foundation
import LottieSettings
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import LottieComponent
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
import TextSelectionNode
import InvisibleInkDustNode
import ShimmerEffect
import WalletContext

private enum TransferCardStatus: Equatable {
    case waiting
    case pending
    case completed
    case unavailable
}

private struct TransferCardWalletState: Equatable {
    let status: TransferCardStatus
    let operationId: String?
    let transactionHash: Data?
}

private enum TransferCardRibbonGeometry {
    static let size = CGSize(width: 68.0, height: 68.0)

    static let path: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 62.376457, y: 34.376457))
        path.addLine(to: CGPoint(x: 33.623550, y: 5.623550))
        path.addCurve(to: CGPoint(x: 29.299419, y: 1.768318), control1: CGPoint(x: 31.548130, y: 3.548130), control2: CGPoint(x: 30.510420, y: 2.510418))
        path.addCurve(to: CGPoint(x: 25.830782, y: 0.331558), control1: CGPoint(x: 28.225752, y: 1.110374), control2: CGPoint(x: 27.055216, y: 0.625519))
        path.addCurve(to: CGPoint(x: 20.047100, y: 0.0), control1: CGPoint(x: 24.449732, y: 0.0), control2: CGPoint(x: 22.982187, y: 0.0))
        path.addLine(to: CGPoint(x: 7.725484, y: 0.0))
        path.addCurve(to: CGPoint(x: 3.529531, y: 0.479187), control1: CGPoint(x: 5.302220, y: 0.0), control2: CGPoint(x: 4.090588, y: 0.0))
        path.addCurve(to: CGPoint(x: 2.834592, y: 2.156917), control1: CGPoint(x: 3.042711, y: 0.894974), control2: CGPoint(x: 2.784362, y: 1.518680))
        path.addCurve(to: CGPoint(x: 5.462745, y: 5.462745), control1: CGPoint(x: 2.892483, y: 2.892483), control2: CGPoint(x: 3.749237, y: 3.749237))
        path.addLine(to: CGPoint(x: 62.537258, y: 62.537258))
        path.addCurve(to: CGPoint(x: 65.843079, y: 65.165405), control1: CGPoint(x: 64.250763, y: 64.250763), control2: CGPoint(x: 65.107521, y: 65.107521))
        path.addCurve(to: CGPoint(x: 67.520813, y: 64.470466), control1: CGPoint(x: 66.481316, y: 65.215637), control2: CGPoint(x: 67.105026, y: 64.957290))
        path.addCurve(to: CGPoint(x: 68.0, y: 60.274517), control1: CGPoint(x: 68.0, y: 63.909412), control2: CGPoint(x: 68.0, y: 62.697780))
        path.addLine(to: CGPoint(x: 68.0, y: 47.952900))
        path.addCurve(to: CGPoint(x: 67.668442, y: 42.169220), control1: CGPoint(x: 68.0, y: 45.017814), control2: CGPoint(x: 68.0, y: 43.550270))
        path.addCurve(to: CGPoint(x: 66.231682, y: 38.700580), control1: CGPoint(x: 67.374481, y: 40.944782), control2: CGPoint(x: 66.889626, y: 39.774246))
        path.addCurve(to: CGPoint(x: 62.376457, y: 34.376457), control1: CGPoint(x: 65.489578, y: 37.489582), control2: CGPoint(x: 64.451874, y: 36.451874))
        path.closeSubpath()
        return path
    }()

    static func compactPath(center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let radius: CGFloat = 7.0
        func point(_ angle: CGFloat) -> CGPoint {
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }

        let angles: [CGFloat] = [-.pi / 4.0, -.pi / 2.0, -.pi * 5.0 / 4.0, -.pi * 2.0, -.pi * 9.0 / 4.0]
        path.move(to: point(angles[0]))
        for corner in 0 ..< 4 {
            let startAngle = angles[corner]
            let step = (angles[corner + 1] - startAngle) / 3.0
            let controlLength = 4.0 / 3.0 * tan(step / 4.0) * radius
            path.addLine(to: point(startAngle))
            for segment in 0 ..< 3 {
                let angle = startAngle + CGFloat(segment) * step
                let nextAngle = angle + step
                let start = point(angle)
                let end = point(nextAngle)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: start.x - sin(angle) * controlLength, y: start.y + cos(angle) * controlLength),
                    control2: CGPoint(x: end.x + sin(nextAngle) * controlLength, y: end.y - cos(nextAngle) * controlLength)
                )
            }
        }
        path.closeSubpath()
        return path
    }
}

private func transferCardTransactionHash(_ value: String?) -> Data? {
    guard let value else {
        return nil
    }
    let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    if parts.count == 2 && UInt64(parts[0]) == nil {
        return nil
    }
    guard let hash = parts.last.flatMap({ Data(base64Encoded: String($0)) }), hash.count == 32 else {
        return nil
    }
    return hash
}

private func transferCardWalletState(_ state: WalletContext.State, operationId: String?, transactionHash: Data?) -> TransferCardWalletState? {
    if let transaction = state.transactions.items.first(where: { transaction in
        guard transaction.direction == .outgoing, transaction.collectible == nil, transaction.kind == .transfer else {
            return false
        }
        return operationId.map { transaction.presentationId == "pending:\($0)" } == true
            || (transactionHash != nil && transferCardTransactionHash(transaction.transactionHash ?? transaction.id) == transactionHash)
    }) {
        let status: TransferCardStatus
        switch transaction.status {
        case .pending:
            status = .pending
        case .completed:
            status = .completed
        case .failed:
            status = .unavailable
        }
        return TransferCardWalletState(
            status: status,
            operationId: operationId ?? (transaction.presentationId.hasPrefix("pending:") ? String(transaction.presentationId.dropFirst("pending:".count)) : nil),
            transactionHash: transferCardTransactionHash(transaction.transactionHash ?? transaction.id) ?? transactionHash
        )
    }
    if let pending = state.pendingTransfers.first(where: { pending in
        pending.collectibleAddress == nil && (pending.id == operationId
            || (transactionHash != nil && transferCardTransactionHash(pending.transactionHash) == transactionHash))
    }) {
        let status: TransferCardStatus
        switch pending.status {
        case .broadcasting:
            status = .waiting
        case .pending, .submissionUnknown:
            status = .pending
        case .confirmed:
            status = .completed
        }
        return TransferCardWalletState(status: status, operationId: pending.id, transactionHash: transferCardTransactionHash(pending.transactionHash) ?? transactionHash)
    }
    return nil
}

private final class TransferCardShimmerView: UIView {
    private let surfaceView = ShimmerEffectForegroundView()
    private let borderView = ShimmerEffectForegroundView()
    private let borderMaskView = UIView()
    private let addressView = ShimmerEffectForegroundView()

    init(addressMask: UIView) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.cornerRadius = 20.0

        self.borderMaskView.layer.cornerRadius = 20.0
        self.borderMaskView.layer.borderWidth = 2.0
        self.borderMaskView.layer.borderColor = UIColor.white.cgColor
        self.borderView.mask = self.borderMaskView
        self.addressView.mask = addressMask

        for (view, color) in [(self.surfaceView, UIColor(rgb: 0x17c8fd, alpha: 0.45)), (self.borderView, UIColor(rgb: 0x17c8fd, alpha: 0.85)), (self.addressView, UIColor(rgb: 0x15e7fd).withAlphaComponent(0.9))] {
            view.update(backgroundColor: .clear, foregroundColor: color, gradientSize: 70.0, globalTimeOffset: true, duration: 2.2, horizontal: true)
            self.addSubview(view)
        }
        self.surfaceView.layer.compositingFilter = "overlayBlendMode"
        self.borderView.layer.compositingFilter = "overlayBlendMode"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, addressFrame: CGRect) {
        let bounds = CGRect(origin: .zero, size: size)
        self.frame = bounds
        self.surfaceView.frame = bounds
        self.borderView.frame = bounds
        self.borderMaskView.frame = bounds
        self.addressView.frame = addressFrame
        self.addressView.mask?.frame = CGRect(origin: .zero, size: addressFrame.size)

        let containerSize = CGSize(width: size.width * 9.0, height: size.height)
        let surfaceRect = bounds.offsetBy(dx: size.width * 4.0, dy: 0.0)
        self.surfaceView.updateAbsoluteRect(surfaceRect, within: containerSize)
        self.borderView.updateAbsoluteRect(surfaceRect, within: containerSize)
        self.addressView.updateAbsoluteRect(addressFrame.offsetBy(dx: surfaceRect.minX, dy: 0.0), within: containerSize)
    }
}

public final class ChatMessageTransferBubbleContentNode: ChatMessageBubbleContentNode {
    private let labelNode: TextNode
    private var labelBackgroundNode: WallpaperBubbleBackgroundNode?
    private let labelBackgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?

    private let mediaContainerNode: ASDisplayNode
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let cardNode: ASDisplayNode
    private let cardBackgroundNode: ASImageNode
    private var cardIcon = ComponentView<Empty>()
    private var cardIconPlayedOnce = false
    private let amountNode: TextNode
    private let nameNode: TextNode
    private let addressNode: TextNode
    private let addressShimmerMaskNode: TextNode
    private var shimmerView: TransferCardShimmerView?
    private let sendingClockNode: ASDisplayNode
    private let clockFrameNode: ASImageNode
    private let clockMinNode: ASImageNode
    private let captionNode: TextNode
    private var captionTextSelectionNode: TextSelectionNode?
    private var captionDustNode: InvisibleInkDustNode?
    private let ribbonBackgroundNode: ASImageNode
    private let ribbonTextNode: TextNode
    private let ribbonTextContainerNode: ASDisplayNode
    private let ribbonTextMaskNode: ASImageNode
    private var ribbonAnimationLayer: SimpleShapeLayer?
    private var ribbonAnimationMaskLayer: SimpleShapeLayer?
    private var completionAnimationId = 0

    private weak var walletContext: WalletContext?
    private var walletStateDisposable: MetaDisposable?
    private var renderedFiatState: WalletContext.FiatState?
    private var transferOperationId: String?
    private var transferTransactionHash: Data?
    private var transferStatus: TransferCardStatus?
    private var isIncomingTransfer = false

    #if DEBUG
    private var debugTransferStatus: TransferCardStatus?
    #endif

    private var displayedTransferStatus: TransferCardStatus? {
        #if DEBUG
        if let debugTransferStatus = self.debugTransferStatus {
            return debugTransferStatus
        }
        #endif
        return self.transferStatus
    }

    private var isSendingTransfer: Bool {
        return !self.isIncomingTransfer && self.displayedTransferStatus != nil && self.displayedTransferStatus != .completed
    }

    private var cachedLabelBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?

    override public var disablesClipping: Bool {
        return true
    }

    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if (oldValue != .none) != (self.visibility != .none) {
                if self.visibility == .none {
                    self.finishCompletionAnimation()
                }
                self.updateSendingClockAnimation()
                self.updateShimmer(animated: false)
            }
        }
    }

    required public init(lottieSettings: LottieRenderingSettings) {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.labelBackgroundMaskNode = ASImageNode()
        self.labelBackgroundMaskNode.displaysAsynchronously = false

        self.mediaContainerNode = ASDisplayNode()
        self.mediaContainerNode.clipsToBounds = false

        self.cardNode = ASDisplayNode()
        self.cardNode.isUserInteractionEnabled = false
        self.cardNode.clipsToBounds = true
        self.cardNode.cornerRadius = 20.0

        self.cardBackgroundNode = ASImageNode()
        self.cardBackgroundNode.displaysAsynchronously = false
        self.cardBackgroundNode.displayWithoutProcessing = true
        self.cardBackgroundNode.contentMode = .scaleAspectFill
        self.cardBackgroundNode.image = UIImage(bundleImageName: "Wallet/CardChatMock")

        self.amountNode = TextNode()
        self.amountNode.isUserInteractionEnabled = false
        self.amountNode.displaysAsynchronously = false

        self.nameNode = TextNode()
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.displaysAsynchronously = false

        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        self.addressNode.displaysAsynchronously = false

        self.addressShimmerMaskNode = TextNode()
        self.addressShimmerMaskNode.isUserInteractionEnabled = false
        self.addressShimmerMaskNode.displaysAsynchronously = false

        self.sendingClockNode = ASDisplayNode()
        self.sendingClockNode.isUserInteractionEnabled = false
        self.sendingClockNode.alpha = 0.0

        self.clockFrameNode = ASImageNode()
        self.clockFrameNode.isLayerBacked = true
        self.clockFrameNode.displaysAsynchronously = false
        self.clockFrameNode.displayWithoutProcessing = true

        self.clockMinNode = ASImageNode()
        self.clockMinNode.isLayerBacked = true
        self.clockMinNode.displaysAsynchronously = false
        self.clockMinNode.displayWithoutProcessing = true

        self.captionNode = TextNode()
        self.captionNode.isUserInteractionEnabled = false
        self.captionNode.displaysAsynchronously = false

        self.ribbonBackgroundNode = ASImageNode()
        self.ribbonBackgroundNode.displaysAsynchronously = false
        self.ribbonBackgroundNode.displayWithoutProcessing = true
        self.ribbonBackgroundNode.image = generateTintedImage(
            image: UIImage(bundleImageName: "Chat/Message/GiftRibbon"),
            color: .white
        )

        self.ribbonTextNode = TextNode()
        self.ribbonTextNode.isUserInteractionEnabled = false
        self.ribbonTextNode.displaysAsynchronously = false

        self.ribbonTextContainerNode = ASDisplayNode()
        self.ribbonTextContainerNode.isUserInteractionEnabled = false
        self.ribbonTextMaskNode = ASImageNode()
        self.ribbonTextMaskNode.displaysAsynchronously = false
        self.ribbonTextMaskNode.displayWithoutProcessing = true
        self.ribbonTextMaskNode.image = UIImage(bundleImageName: "Chat/Message/GiftRibbon")

        super.init(lottieSettings: lottieSettings)

        self.cardNode.addSubnode(self.cardBackgroundNode)
        self.cardNode.addSubnode(self.amountNode)
        self.cardNode.addSubnode(self.nameNode)
        self.cardNode.addSubnode(self.addressNode)
        self.cardNode.addSubnode(self.sendingClockNode)
        self.sendingClockNode.addSubnode(self.clockFrameNode)
        self.sendingClockNode.addSubnode(self.clockMinNode)

        self.addSubnode(self.mediaContainerNode)
        self.mediaContainerNode.addSubnode(self.cardNode)
        self.mediaContainerNode.addSubnode(self.ribbonBackgroundNode)
        self.mediaContainerNode.addSubnode(self.ribbonTextContainerNode)
        self.ribbonTextContainerNode.addSubnode(self.ribbonTextNode)
        self.mediaContainerNode.addSubnode(self.captionNode)
        self.addSubnode(self.labelNode)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.walletStateDisposable?.dispose()
    }

    private func updateWalletSubscription(item: ChatMessageBubbleContentItem, isIncoming: Bool, transactionId: String, fiatState: WalletContext.FiatState?, isSameMessage: Bool) {
        if !isSameMessage {
            self.walletStateDisposable?.dispose()
            self.walletStateDisposable = nil
            self.transferOperationId = nil
            self.transferTransactionHash = nil
            self.transferStatus = nil
            #if DEBUG
            self.debugTransferStatus = nil
            #endif
            self.finishCompletionAnimation()
            self.shimmerView?.removeFromSuperview()
            self.shimmerView = nil
        }

        let walletContext = item.context.walletContext
        if self.walletContext !== walletContext {
            self.walletStateDisposable?.dispose()
            self.walletStateDisposable = nil
            self.walletContext = walletContext
        }

        self.renderedFiatState = fiatState
        self.requestWalletFiatUpdateIfNeeded()

        if isIncoming {
            self.updateTransferStatus(.completed, animated: false)
        } else {
            let pending = item.message.attributes.compactMap { $0 as? PendingWalletTransferMessageAttribute }.first
            self.transferOperationId = pending?.operationId ?? self.transferOperationId
            self.transferTransactionHash = transferCardTransactionHash(pending?.transactionId)
                ?? transferCardTransactionHash(transactionId)
                ?? self.transferTransactionHash

            self.applyWalletState(walletContext.flatMap {
                transferCardWalletState($0.stateValue, operationId: self.transferOperationId, transactionHash: self.transferTransactionHash)
            }, animated: isSameMessage)
        }

        guard self.walletStateDisposable == nil, let walletContext else {
            return
        }
        let disposable = MetaDisposable()
        self.walletStateDisposable = disposable
        disposable.set((walletContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else {
                return
            }
            if self.transferStatus != .completed {
                self.applyWalletState(
                    transferCardWalletState(state, operationId: self.transferOperationId, transactionHash: self.transferTransactionHash),
                    animated: true
                )
            }
            self.requestWalletFiatUpdateIfNeeded()
        }))
    }

    private func requestWalletFiatUpdateIfNeeded() {
        Queue.mainQueue().justDispatch { [weak self] in
            guard let self, let item = self.item, let fiatState = self.walletContext?.stateValue.fiat else {
                return
            }
            guard self.renderedFiatState?.selectedCurrency != fiatState.selectedCurrency
                || self.renderedFiatState?.selectedRate?.unitsPerGram != fiatState.selectedRate?.unitsPerGram else {
                return
            }
            item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
        }
    }

    private func applyWalletState(_ state: TransferCardWalletState?, animated: Bool) {
        if let state {
            self.transferOperationId = state.operationId ?? self.transferOperationId
            self.transferTransactionHash = state.transactionHash ?? self.transferTransactionHash
            self.updateTransferStatus(state.status, animated: animated)
        } else if self.transferStatus == .pending || self.transferStatus == .unavailable {
            self.updateTransferStatus(.unavailable, animated: animated)
        } else {
            self.updateTransferStatus(self.transferOperationId == nil ? .completed : .waiting, animated: animated)
        }
    }

    private func updateTransferStatus(_ status: TransferCardStatus, animated: Bool) {
        guard self.transferStatus != .completed else {
            return
        }
        let previousStatus = self.displayedTransferStatus
        self.transferStatus = status
        self.updateTransferAppearance(previousStatus: previousStatus, animated: animated)
    }

    private func updateTransferAppearance(previousStatus: TransferCardStatus?, animated: Bool) {
        let status = self.displayedTransferStatus
        if previousStatus == status {
            if status == .pending {
                self.updateShimmer(animated: false)
            }
            return
        }
        self.finishCompletionAnimation()
        self.updateShimmer(animated: animated && previousStatus != nil)
        let animateCompletion = !self.isIncomingTransfer && status == .completed && previousStatus != nil && animated && self.visibility != .none
        if animateCompletion {
            self.animateCompletion()
        }
    }

    private func updateSendingClockAnimation() {
        let shouldAnimate = self.isSendingTransfer && self.visibility != .none
        for (node, duration) in [(self.clockFrameNode, 6.0), (self.clockMinNode, 1.0)] {
            let key = "transferClockRotation"
            if shouldAnimate {
                if node.layer.animation(forKey: key) == nil {
                    node.layer.transform = CATransform3DIdentity
                    let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                    animation.fromValue = 0.0 as NSNumber
                    animation.toValue = (Double.pi * 2.0) as NSNumber
                    animation.duration = duration
                    animation.repeatCount = .infinity
                    animation.timingFunction = CAMediaTimingFunction(name: .linear)
                    node.layer.add(animation, forKey: key)
                }
            } else if node.layer.animation(forKey: key) != nil {
                let transform = node.layer.presentation()?.transform ?? CATransform3DIdentity
                node.layer.removeAnimation(forKey: key)
                node.layer.transform = transform
            }
        }
    }

    private func updateShimmer(animated: Bool) {
        let displayShimmer = self.displayedTransferStatus == .pending && self.visibility != .none
        if displayShimmer {
            let shimmerView: TransferCardShimmerView
            if let current = self.shimmerView {
                shimmerView = current
            } else {
                shimmerView = TransferCardShimmerView(addressMask: self.addressShimmerMaskNode.view)
                self.shimmerView = shimmerView
                self.cardNode.view.addSubview(shimmerView)
            }
            shimmerView.layer.removeAnimation(forKey: "opacity")
            shimmerView.alpha = 1.0
            shimmerView.update(size: self.cardNode.bounds.size, addressFrame: self.addressNode.frame)
            self.addressShimmerMaskNode.recursivelyEnsureDisplaySynchronously(true)
        } else if let shimmerView = self.shimmerView {
            if animated && self.visibility != .none {
                guard shimmerView.alpha != 0.0 else {
                    return
                }
                shimmerView.alpha = 0.0
                shimmerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, completion: { [weak self, weak shimmerView] finished in
                    guard finished, let self, let shimmerView, self.shimmerView === shimmerView, shimmerView.alpha == 0.0 else {
                        return
                    }
                    shimmerView.removeFromSuperview()
                    self.shimmerView = nil
                })
            } else {
                shimmerView.removeFromSuperview()
                self.shimmerView = nil
            }
        }
    }

    private func removeRibbonAnimation() {
        self.ribbonAnimationLayer?.removeAllAnimations()
        self.ribbonAnimationLayer?.removeFromSuperlayer()
        self.ribbonAnimationLayer = nil
        if let ribbonAnimationMaskLayer = self.ribbonAnimationMaskLayer {
            ribbonAnimationMaskLayer.removeAllAnimations()
            self.ribbonAnimationMaskLayer = nil
            self.ribbonTextContainerNode.layer.mask = nil
        }
        self.ribbonTextContainerNode.view.mask = self.ribbonTextMaskNode.view
    }

    private func finishCompletionAnimation() {
        self.completionAnimationId &+= 1
        self.removeRibbonAnimation()
        self.ribbonBackgroundNode.layer.removeAnimation(forKey: "opacity")
        self.ribbonTextNode.layer.removeAnimation(forKey: "opacity")
        self.ribbonTextNode.layer.removeAnimation(forKey: "transform.scale")
        self.sendingClockNode.layer.removeAnimation(forKey: "opacity")
        self.sendingClockNode.layer.removeAnimation(forKey: "transform.scale")
        self.mediaContainerNode.layer.removeAnimation(forKey: "transform.scale")
        let sending = self.isSendingTransfer
        self.sendingClockNode.alpha = sending ? 1.0 : 0.0
        self.ribbonBackgroundNode.alpha = sending ? 0.0 : 1.0
        self.ribbonTextContainerNode.alpha = sending ? 0.0 : 1.0
        self.ribbonTextNode.alpha = 1.0
        ContainedViewLayoutTransition.immediate.updateTintColor(
            layer: self.ribbonBackgroundNode.layer,
            color: UIColor(rgb: self.isIncomingTransfer ? 0x0075f6 : 0x00cf00)
        )
        self.updateSendingClockAnimation()
    }

    private func animateCompletion() {
        let animationId = self.completionAnimationId
        let ribbonFrame = self.ribbonBackgroundNode.frame
        let clockCenter = CGPoint(
            x: self.cardNode.frame.minX + self.sendingClockNode.position.x - ribbonFrame.minX,
            y: self.cardNode.frame.minY + self.sendingClockNode.position.y - ribbonFrame.minY
        )
        let finalPath = TransferCardRibbonGeometry.path
        var overshootTransform = CGAffineTransform(a: 1.02, b: 0.02, c: 0.02, d: 1.02, tx: -1.36, ty: -1.36)
        let paths = [
            TransferCardRibbonGeometry.compactPath(center: clockCenter),
            finalPath,
            finalPath.copy(using: &overshootTransform) ?? finalPath,
            finalPath
        ]
        let keyTimes = [0.0, 0.28 / 0.42, 0.34 / 0.42, 1.0].map { NSNumber(value: $0) }

        let ribbonLayer = SimpleShapeLayer()
        ribbonLayer.frame = ribbonFrame
        ribbonLayer.contentsScale = UIScreenScale
        ribbonLayer.fillColor = UIColor(rgb: 0x00cf00).cgColor
        ribbonLayer.path = finalPath
        self.ribbonAnimationLayer = ribbonLayer
        self.mediaContainerNode.layer.insertSublayer(ribbonLayer, below: self.ribbonBackgroundNode.layer)
        self.ribbonBackgroundNode.alpha = 0.0

        let maskLayer = SimpleShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: ribbonFrame.size)
        maskLayer.contentsScale = UIScreenScale
        maskLayer.fillColor = UIColor.white.cgColor
        maskLayer.path = finalPath
        self.ribbonAnimationMaskLayer = maskLayer
        self.ribbonTextContainerNode.view.mask = nil
        self.ribbonTextContainerNode.layer.mask = maskLayer

        for layer in [ribbonLayer, maskLayer] {
            layer.animateKeyframes(values: paths, keyTimes: keyTimes, duration: 0.42, keyPath: "path", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
        }
        ribbonLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
        self.sendingClockNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12)
        self.sendingClockNode.layer.animateScale(from: 1.0, to: 0.4, duration: 0.12)
        self.ribbonTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.22, delay: 0.06)
        self.ribbonTextNode.layer.animateScale(from: 0.65, to: 1.0, duration: 0.28)

        self.ribbonBackgroundNode.alpha = 1.0
        self.ribbonBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.06, delay: 0.42, completion: { [weak self] finished in
            guard finished, let self, self.completionAnimationId == animationId else {
                return
            }
            self.removeRibbonAnimation()
        })
        self.mediaContainerNode.layer.animateKeyframes(
            values: [1.0 as NSNumber, 1.03 as NSNumber, 1.0 as NSNumber],
            keyTimes: [0.0, 0.28 / 0.58, 1.0].map { NSNumber(value: $0) },
            duration: 0.58,
            keyPath: "transform.scale",
            timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue,
            completion: { [weak self] finished in
                guard finished, let self, self.completionAnimationId == animationId else {
                    return
                }
                self.finishCompletionAnimation()
            }
        )
    }

    #if DEBUG
    private func toggleDebugTransferStatus() {
        guard !self.isIncomingTransfer else {
            return
        }
        let previousStatus = self.displayedTransferStatus
        self.debugTransferStatus = previousStatus == .completed ? .pending : .completed
        self.updateTransferAppearance(previousStatus: previousStatus, animated: true)
    }
    #endif

    private func removeCaptionTextSelection(animated: Bool) {
        guard let textSelectionNode = self.captionTextSelectionNode else {
            return
        }
        self.captionTextSelectionNode = nil
        self.updateIsTextSelectionActive?(false)

        if animated {
            textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.highlightAreaNode.removeFromSupernode()
                textSelectionNode?.removeFromSupernode()
            })
        } else {
            textSelectionNode.highlightAreaNode.removeFromSupernode()
            textSelectionNode.removeFromSupernode()
        }
    }

    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value {
            self.removeCaptionTextSelection(animated: true)
        }
    }

    override public func updateIsExtractedToContextPreview(_ value: Bool) {
        if value {
            guard self.captionTextSelectionNode == nil,
                  let item = self.item,
                  !self.captionNode.isHidden,
                  let attributedText = self.captionNode.cachedLayout?.attributedString,
                  attributedText.length > 0,
                  let rootNode = item.controllerInteraction.chatControllerNode() else {
                return
            }

            let knobColor: UIColor
            if item.message.effectivelyIncoming(item.context.account.peerId) {
                knobColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionKnobColor
            } else {
                knobColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionKnobColor
            }

            let textSelectionNode = TextSelectionNode(
                theme: TextSelectionTheme(
                    selection: UIColor.white.withAlphaComponent(0.4),
                    knob: knobColor,
                    isDark: item.presentationData.theme.theme.overallDarkAppearance
                ),
                strings: item.presentationData.strings,
                textNodeOrView: .node(self.captionNode),
                updateIsActive: { [weak self] value in
                    self?.updateIsTextSelectionActive?(value)
                },
                present: { [weak self] controller, arguments in
                    self?.item?.controllerInteraction.presentGlobalOverlayController(controller, arguments)
                },
                rootView: { [weak rootNode] in
                    return rootNode?.view
                },
                performAction: { [weak self] text, action in
                    guard let self, let item = self.item else {
                        return
                    }
                    item.controllerInteraction.performTextSelectionAction(item.message, true, text, nil, action)
                }
            )
            textSelectionNode.enableCopy = true
            textSelectionNode.enableQuote = false
            textSelectionNode.enableShare = true

            self.captionTextSelectionNode = textSelectionNode
            self.mediaContainerNode.addSubnode(textSelectionNode)
            self.mediaContainerNode.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.captionNode)
            textSelectionNode.frame = self.captionNode.frame
            textSelectionNode.highlightAreaNode.frame = textSelectionNode.frame
        } else {
            self.removeCaptionTextSelection(animated: true)
        }
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeAmountLayout = TextNode.asyncLayout(self.amountNode)
        let makeNameLayout = TextNode.asyncLayout(self.nameNode)
        let makeAddressLayout = TextNode.asyncLayout(self.addressNode)
        let makeAddressShimmerMaskLayout = TextNode.asyncLayout(self.addressShimmerMaskNode)
        let makeCaptionLayout = TextNode.asyncLayout(self.captionNode)
        let makeRibbonTextLayout = TextNode.asyncLayout(self.ribbonTextNode)
        let cachedLabelBackgroundImage = self.cachedLabelBackgroundImage

        return { [weak self] item, _, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(
                hidesSimpleAuthorHeader: true,
                headerSpacing: 0.0,
                hidesBackground: .always,
                forceFullCorners: false,
                forceAlignment: .center
            )

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, _ in
                let engineMessage = EngineMessage(item.message)
                guard let action = item.message.media.first(where: { media in
                    guard let action = media as? TelegramMediaAction else {
                        return false
                    }
                    if case .gramTransfer = action.action {
                        return true
                    } else {
                        return false
                    }
                }) as? TelegramMediaAction else {
                    return (0.0, { _ in
                        return (CGSize(), { _, _, _ in })
                    })
                }
                guard case let .gramTransfer(amount, peerAddress, transactionId, comment, commentEncrypted) = action.action else {
                    return (0.0, { _ in
                        return (CGSize(), { _, _, _ in })
                    })
                }
                let isIncoming = engineMessage.effectivelyIncoming(item.context.account.peerId)
                let caption = commentEncrypted ? "" : (comment ?? "")
                let hasEncryptedCaption = commentEncrypted && comment?.isEmpty == false

                let fiatState = item.context.walletContext?.stateValue.fiat
                let fiatValue: String?
                if let fiatState, let rate = fiatState.selectedRate {
                    fiatValue = formatTonFiatValue(
                        amount,
                        rate: rate.unitsPerGram,
                        currencySymbol: fiatState.selectedCurrency.symbol,
                        dateTimeFormat: item.presentationData.dateTimeFormat
                    )
                } else {
                    fiatValue = nil
                }
                let serviceText = walletTransferServiceMessageString(
                    presentationData: (item.presentationData.theme.theme, item.presentationData.theme.wallpaper),
                    strings: item.presentationData.strings,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    message: engineMessage,
                    isIncoming: isIncoming,
                    amount: amount,
                    fiatValue: fiatValue
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
                if isIncoming {
                    sign = "+"
                } else {
                    sign = "−"
                }
                let formattedAmount = formatTonAmountText(
                    amount,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    maxDecimalPositions: 3
                )
                let localizedAmount = formatTonAmountText(
                    amount,
                    dateTimeFormat: item.presentationData.dateTimeFormat,
                    maxDecimalPositions: 3,
                    formatString: item.presentationData.strings.Currency_Grams
                )
                let amountText = NSMutableAttributedString(
                    string: localizedAmount,
                    font: amountFont,
                    textColor: UIColor(rgb: 0x0fddff)
                )
                let amountRange = (localizedAmount as NSString).range(of: formattedAmount)
                if amountRange.location != NSNotFound {
                    amountText.replaceCharacters(in: amountRange, with: tonAmountAttributedString(
                        sign + formattedAmount,
                        integralFont: amountFont,
                        fractionalFont: fractionalAmountFont,
                        color: .white,
                        decimalSeparator: item.presentationData.dateTimeFormat.decimalSeparator
                    ))
                }
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

                var addressGroups: [String] = []
                var addressIndex = peerAddress.startIndex
                while addressIndex < peerAddress.endIndex {
                    let endIndex = peerAddress.index(addressIndex, offsetBy: 4, limitedBy: peerAddress.endIndex) ?? peerAddress.endIndex
                    addressGroups.append(String(peerAddress[addressIndex ..< endIndex]))
                    addressIndex = endIndex
                }
                let (addressLayout, addressApply) = makeAddressLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: addressGroups.joined(separator: " "),
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
                let (_, addressShimmerMaskApply) = makeAddressShimmerMaskLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: addressGroups.joined(separator: " "),
                        font: Font.with(size: 10.0, design: .monospace, weight: .medium),
                        textColor: .white,
                        paragraphAlignment: .center
                    ),
                    backgroundColor: nil,
                    maximumNumberOfLines: 2,
                    truncationType: .end,
                    constrainedSize: CGSize(width: cardSize.width - 24.0, height: CGFloat.greatestFiniteMagnitude),
                    alignment: .center,
                    lineSpacing: 0.05,
                    cutout: nil,
                    insets: UIEdgeInsets()
                ))

                let hasCaption = hasEncryptedCaption || !caption.isEmpty
                let (captionLayout, captionApply) = makeCaptionLayout(TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: caption,
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
                let captionSize = hasEncryptedCaption
                    ? CGSize(width: 120.0, height: ceil(Font.regular(13.0).lineHeight))
                    : captionLayout.size

                let ribbonTitle: String
                if isIncoming {
                    //TODO:localize
                    ribbonTitle = "received"
                } else {
                    //TODO:localize
                    ribbonTitle = "sent"
                }
                let ribbonTextLayoutArguments = TextNodeLayoutArguments(
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
                )
                let (ribbonTextLayout, ribbonTextApply) = makeRibbonTextLayout(ribbonTextLayoutArguments)

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
                    height: cardSize.height + outerInset * 2.0 + captionSpacing + (hasCaption ? captionSize.height : 0.0) + captionBottomInset
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
                        let isSameMessage = self.item?.context.account === item.context.account
                            && self.item?.message.id.peerId == item.message.id.peerId
                            && self.item?.message.stableId == item.message.stableId
                        if !isSameMessage {
                            self.cardIcon.view?.removeFromSuperview()
                            self.cardIcon = ComponentView<Empty>()
                        }
                        self.item = item
                        self.isIncomingTransfer = isIncoming

                        let _ = labelApply()
                        let _ = amountApply()
                        let _ = nameApply()
                        let _ = addressApply()
                        let _ = addressShimmerMaskApply()
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
                            origin: CGPoint(x: outerInset, y: outerInset),
                            size: cardSize
                        )
                        if self.mediaContainerNode.frame != mediaFrame {
                            self.finishCompletionAnimation()
                        }
                        animation.animator.updateFrame(layer: self.mediaContainerNode.layer, frame: mediaFrame, completion: nil)
                        self.cardNode.frame = cardFrame
                        self.cardBackgroundNode.frame = CGRect(origin: .zero, size: cardSize)

                        let clockSize = CGSize(width: 14.0, height: 14.0)
                        self.sendingClockNode.frame = CGRect(origin: CGPoint(x: cardSize.width - clockSize.width - 12.0, y: 12.0), size: clockSize)
                        for node in [self.clockFrameNode, self.clockMinNode] {
                            node.bounds = CGRect(origin: .zero, size: clockSize)
                            node.position = CGPoint(x: clockSize.width * 0.5, y: clockSize.height * 0.5)
                        }
                        if self.clockFrameNode.image == nil {
                            let graphics = PresentationResourcesChat.principalGraphics(
                                theme: item.presentationData.theme.theme,
                                wallpaper: item.presentationData.theme.wallpaper,
                                bubbleCorners: item.presentationData.chatBubbleCorners
                            )
                            let clockColor = UIColor(rgb: 0x5ec2ff)
                            self.clockFrameNode.image = generateTintedImage(image: graphics.clockMediaFrameImage, color: clockColor)
                            self.clockMinNode.image = generateTintedImage(image: graphics.clockMediaMinImage, color: clockColor)
                        }

                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let iconFrame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - iconSize.width) * 0.5), y: 18.0),
                            size: iconSize
                        )
                        let animationSize = CGSize(width: 48.0, height: 48.0)
                        let _ = self.cardIcon.update(
                            transition: .immediate,
                            component: AnyComponent(LottieComponent(
                                content: LottieComponent.AppBundleContent(name: "GramDiamondLight"),
                                startingPosition: .begin,
                                size: animationSize,
                                loop: false,
                                lottieSettings: item.context.lottieRenderingSettings
                            )),
                            environment: {},
                            containerSize: animationSize
                        )
                        if let iconView = self.cardIcon.view as? LottieComponent.View {
                            iconView.externalShouldPlay = self.visibility != .none
                            if iconView.superview == nil {
                                iconView.isUserInteractionEnabled = false
                                self.cardNode.view.addSubview(iconView)
                            }
                            iconView.frame = CGRect(
                                x: iconFrame.midX - animationSize.width * 0.5,
                                y: iconFrame.midY - animationSize.height * 0.5,
                                width: animationSize.width,
                                height: animationSize.height
                            )
                            
                            if !self.cardIconPlayedOnce {
                                self.cardIconPlayedOnce = true
                                iconView.playOnce()
                            }
                        }
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
                        self.addressShimmerMaskNode.frame = CGRect(origin: .zero, size: addressLayout.size)

                        let ribbonSize = TransferCardRibbonGeometry.size
                        let ribbonFrame = CGRect(
                            origin: CGPoint(x: cardFrame.maxX - ribbonSize.width + 2.0, y: cardFrame.minY - 2.0),
                            size: ribbonSize
                        )
                        self.ribbonBackgroundNode.frame = ribbonFrame
                        self.ribbonTextContainerNode.frame = ribbonFrame
                        self.ribbonTextMaskNode.frame = CGRect(origin: .zero, size: ribbonSize)
                        if let ribbonAnimationMaskLayer = self.ribbonAnimationMaskLayer {
                            ribbonAnimationMaskLayer.frame = CGRect(origin: .zero, size: ribbonSize)
                        } else {
                            self.ribbonTextContainerNode.view.mask = self.ribbonTextMaskNode.view
                        }
                        let ribbonTextPosition = CGPoint(x: ribbonSize.width * 0.5 + 7.0, y: ribbonSize.height * 0.5 - 6.0)
                        self.ribbonTextNode.transform = CATransform3DMakeRotation(.pi / 4.0, 0.0, 0.0, 1.0)
                        self.ribbonTextNode.bounds = CGRect(origin: .zero, size: ribbonTextLayout.size)
                        self.ribbonTextNode.position = ribbonTextPosition

                        self.captionNode.isHidden = !hasCaption || hasEncryptedCaption
                        if hasEncryptedCaption {
                            self.removeCaptionTextSelection(animated: false)
                        } else if let captionDustNode = self.captionDustNode {
                            captionDustNode.removeFromSupernode()
                            self.captionDustNode = nil
                        }
                        if hasCaption {
                            let captionFrame = CGRect(
                                origin: CGPoint(
                                    x: floorToScreenPixels((mediaSize.width - captionSize.width) * 0.5),
                                    y: cardFrame.maxY + captionSpacing
                                ),
                                size: captionSize
                            )
                            self.captionNode.frame = captionFrame
                            if hasEncryptedCaption {
                                let dustNode: InvisibleInkDustNode
                                if let current = self.captionDustNode {
                                    dustNode = current
                                } else {
                                    dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: item.context.sharedContext.energyUsageSettings.fullTranslucency)
                                    dustNode.isUserInteractionEnabled = false
                                    dustNode.isAccessibilityElement = true
                                    //TODO:localize
                                    dustNode.accessibilityLabel = "Encrypted comment"
                                    self.captionDustNode = dustNode
                                    self.mediaContainerNode.addSubnode(dustNode)
                                }
                                dustNode.frame = captionFrame.insetBy(dx: -3.0, dy: -3.0)
                                let rect = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: captionSize).insetBy(dx: 0.0, dy: 2.0)
                                dustNode.update(size: dustNode.frame.size, color: .white, textColor: .white, rects: [rect], wordRects: [rect])
                            }
                            if let textSelectionNode = self.captionTextSelectionNode {
                                let shouldUpdateLayout = textSelectionNode.frame.size != captionFrame.size
                                textSelectionNode.frame = captionFrame
                                textSelectionNode.highlightAreaNode.frame = captionFrame
                                if shouldUpdateLayout {
                                    textSelectionNode.updateLayout()
                                }
                            }
                        } else {
                            self.removeCaptionTextSelection(animated: false)
                            self.captionNode.frame = CGRect()
                        }

                        if self.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true
                            backgroundContent.cornerRadius = 24.0
                            self.mediaBackgroundContent = backgroundContent
                            self.mediaContainerNode.insertSubnode(backgroundContent, at: 0)
                        }
                        if let mediaBackgroundContent = self.mediaBackgroundContent {
                            animation.animator.updateFrame(layer: mediaBackgroundContent.layer, frame: CGRect(origin: .zero, size: mediaSize), completion: nil)
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
                        self.updateWalletSubscription(item: item, isIncoming: isIncoming, transactionId: transactionId, fiatState: fiatState, isSameMessage: isSameMessage)
                        self.shimmerView?.update(size: cardSize, addressFrame: self.addressNode.frame)
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
            y: point.y - textNodeFrame.minY
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
            y: point.y - self.labelNode.frame.minY
        )) {
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                    guard let self, let item = self.item else {
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
                #if DEBUG
                if !self.isIncomingTransfer {
                    return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                        self?.toggleDebugTransferStatus()
                    }))
                }
                #endif
                return ChatMessageBubbleContentTapAction(content: .peerMention(
                    peerId: peerMention.peerId,
                    mention: peerMention.mention,
                    openProfile: false
                ))
            }
        }

        let mediaPoint = self.mediaContainerNode.view.convert(point, from: self.view)
        if self.cardNode.frame.contains(mediaPoint) || self.captionNode.frame.contains(mediaPoint) || self.mediaBackgroundContent?.frame.contains(mediaPoint) == true {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}

private func walletTransferServiceMessageString(
    presentationData: (PresentationTheme, TelegramWallpaper),
    strings: PresentationStrings,
    dateTimeFormat: PresentationDateTimeFormat,
    message: EngineMessage,
    isIncoming: Bool,
    amount: Int64,
    fiatValue: String?
) -> NSAttributedString {
    let primaryTextColor = serviceMessageColorComponents(theme: presentationData.0, wallpaper: presentationData.1).primaryText
    let regularFont = Font.regular(13.0)
    let semiboldFont = Font.semibold(13.0)
    let result = NSMutableAttributedString()

    func append(_ text: String, font: UIFont, additionalAttributes: [NSAttributedString.Key: Any] = [:]) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: primaryTextColor
        ]
        for (key, value) in additionalAttributes {
            attributes[key] = value
        }
        result.append(NSAttributedString(string: text, attributes: attributes))
    }

    let conversationPeer = message.enginePeers[message.id.peerId] ?? message.author
    let peerName = conversationPeer?.compactDisplayTitle ?? ""
    let peerMentionAttributes: [NSAttributedString.Key: Any]
    if let peerId = conversationPeer?.id {
        peerMentionAttributes = [
            NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention): TelegramPeerMention(peerId: peerId, mention: "")
        ]
    } else {
        peerMentionAttributes = [:]
    }

    //TODO:localize
    let youText = "You"
    //TODO:localize
    let sentText = " sent "
    //TODO:localize
    let sentYouText = " sent you "
    //TODO:localize
    let worthPrefixText = " ("
    //TODO:localize
    let worthSuffixText = ")"
    
    if isIncoming {
        append(peerName, font: semiboldFont, additionalAttributes: peerMentionAttributes)
        append(sentYouText, font: regularFont)
    } else {
        append(youText, font: regularFont)
        append(sentText, font: regularFont)
        append(peerName, font: regularFont, additionalAttributes: peerMentionAttributes)
        append(" ", font: regularFont)
    }

    let amountText = formatTonAmountText(
        amount,
        dateTimeFormat: dateTimeFormat,
        maxDecimalPositions: 3,
        formatString: strings.Currency_Grams
    )
    append(amountText, font: semiboldFont)
    
    if let fiatValue {
        append(worthPrefixText, font: regularFont)
        append(fiatValue, font: regularFont)
        append(worthSuffixText, font: regularFont)
    }

    return result
}
