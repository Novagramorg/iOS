import Foundation
import LottieSettings
import UIKit
import Metal
import MetalEngine
import AsyncDisplayKit
import Display
import ComponentFlow
import PremiumDiamondComponent
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
import ChatControllerInteraction
import TextSelectionNode
import InvisibleInkDustNode
import WalletContext
import WalletCardComponent

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
    private static let imageSize = CGSize(width: 54.800781, height: 54.800766)
    static let size = imageSize
    static let center = CGPoint(x: 33.057275 * size.width / imageSize.width, y: 21.743515 * size.height / imageSize.height)

    static let path: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 50.114521, y: 24.658621))
        path.addLine(to: CGPoint(x: 30.142169, y: 4.686269))
        path.addCurve(to: CGPoint(x: 26.538727, y: 1.473573), control1: CGPoint(x: 28.412651, y: 2.956751), control2: CGPoint(x: 27.547891, y: 2.091991))
        path.addCurve(to: CGPoint(x: 23.648195, y: 0.276273), control1: CGPoint(x: 25.643999, y: 0.925288), control2: CGPoint(x: 24.668556, y: 0.521241))
        path.addCurve(to: CGPoint(x: 18.828456, y: 0.0), control1: CGPoint(x: 22.497317, y: 0.0), control2: CGPoint(x: 21.274368, y: 0.0))
        path.addLine(to: CGPoint(x: 4.897057, y: 0.0))
        path.addCurve(to: CGPoint(x: 0.701126, y: 0.479164), control1: CGPoint(x: 2.473808, y: 0.0), control2: CGPoint(x: 1.262181, y: 0.0))
        path.addCurve(to: CGPoint(x: 0.006188, y: 2.156895), control1: CGPoint(x: 0.214309, y: 0.894945), control2: CGPoint(x: -0.044041, y: 1.518656))
        path.addCurve(to: CGPoint(x: 2.634339, y: 5.462719), control1: CGPoint(x: 0.064078, y: 2.892458), control2: CGPoint(x: 0.920832, y: 3.749212))
        path.addLine(to: CGPoint(x: 49.338070, y: 52.166450))
        path.addCurve(to: CGPoint(x: 52.643895, y: 54.794601), control1: CGPoint(x: 51.051577, y: 53.879956), control2: CGPoint(x: 51.908330, y: 54.736710))
        path.addCurve(to: CGPoint(x: 54.321625, y: 54.099662), control1: CGPoint(x: 53.282136, y: 54.844833), control2: CGPoint(x: 53.905845, y: 54.586481))
        path.addCurve(to: CGPoint(x: 54.800818, y: 49.903712), control1: CGPoint(x: 54.800810, y: 53.538617), control2: CGPoint(x: 54.800810, y: 52.326999))
        path.addLine(to: CGPoint(x: 54.800816, y: 35.972328))
        path.addCurve(to: CGPoint(x: 54.524518, y: 31.152596), control1: CGPoint(x: 54.800816, y: 33.526424), control2: CGPoint(x: 54.800813, y: 32.303474))
        path.addCurve(to: CGPoint(x: 53.327218, y: 28.262064), control1: CGPoint(x: 54.279548, y: 30.132233), control2: CGPoint(x: 53.875502, y: 29.156791))
        path.addCurve(to: CGPoint(x: 50.114521, y: 24.658621), control1: CGPoint(x: 52.708799, y: 27.252899), control2: CGPoint(x: 51.844040, y: 26.388140))
        path.closeSubpath()
        var transform = CGAffineTransform(scaleX: size.width / imageSize.width, y: size.height / imageSize.height)
        return path.copy(using: &transform) ?? path
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
    let repeatAnimation: Bool
    var completion: (() -> Void)?

    private let surfaceLayer = SimpleGradientLayer()
    private let borderGlowLayer = SimpleGradientLayer()
    private let borderLayer = SimpleGradientLayer()
    private let borderGlowMask = SimpleShapeLayer()
    private let borderMask = SimpleShapeLayer()
    private let addressView = UIView()
    private let addressLayer = SimpleGradientLayer()
    private var currentLayout: (size: CGSize, addressFrame: CGRect)?
    private var animationStartTime: CFTimeInterval?

    init(addressMask: UIView, repeatAnimation: Bool) {
        self.repeatAnimation = repeatAnimation

        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.cornerRadius = 20.0

        for (mask, width) in [(self.borderGlowMask, CGFloat(4.5)), (self.borderMask, CGFloat(1.3))] {
            mask.fillColor = UIColor.clear.cgColor
            mask.strokeColor = UIColor.white.cgColor
            mask.lineWidth = width
            mask.contentsScale = UIScreenScale
        }
        self.borderGlowLayer.mask = self.borderGlowMask
        self.borderLayer.mask = self.borderMask
        self.addressView.mask = addressMask
        self.addressView.layer.addSublayer(self.addressLayer)

        for (layer, color, peak) in [
            (self.surfaceLayer, UIColor.white, CGFloat(0.07)),
            (self.borderGlowLayer, UIColor.white, CGFloat(0.28)),
            (self.borderLayer, UIColor.white, CGFloat(0.55)),
            (self.addressLayer, UIColor(red: 0.36, green: 0.86, blue: 1.0, alpha: 1.0), CGFloat(0.9))
        ] {
            layer.colors = [CGFloat(0.0), 0.18, 0.6, 1.0, 0.6, 0.18, 0.0].map {
                color.withAlphaComponent(peak * $0).cgColor
            }
            layer.locations = [0.0, 0.22, 0.4, 0.5, 0.6, 0.78, 1.0]
            layer.opacity = 0.0
        }
        for layer in [self.surfaceLayer, self.borderGlowLayer, self.borderLayer] {
            self.layer.addSublayer(layer)
        }
        self.addSubview(self.addressView)
        self.surfaceLayer.compositingFilter = "screenBlendMode"
        self.borderGlowLayer.compositingFilter = "plusL"
        self.borderLayer.compositingFilter = "plusL"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, addressFrame: CGRect) {
        guard size.width > 0.0, size.height > 0.0 else { return }
        if let currentLayout = self.currentLayout, currentLayout.size == size, currentLayout.addressFrame == addressFrame {
            return
        }
        self.currentLayout = (size, addressFrame)
        if self.animationStartTime == nil {
            self.animationStartTime = CACurrentMediaTime() + 0.15
        }

        let bounds = CGRect(origin: .zero, size: size)
        self.frame = bounds
        for layer in [self.surfaceLayer, self.borderGlowLayer, self.borderLayer] {
            layer.frame = bounds
        }
        for mask in [self.borderGlowMask, self.borderMask] {
            mask.frame = bounds
            mask.path = UIBezierPath(roundedRect: bounds, cornerRadius: 20.0).cgPath
        }
        self.addressView.frame = bounds
        self.addressView.mask?.frame = addressFrame
        self.addressLayer.frame = bounds

        for (layer, width, frame) in [
            (self.surfaceLayer, CGFloat(160.0), bounds),
            (self.borderGlowLayer, CGFloat(128.0), bounds),
            (self.borderLayer, CGFloat(112.0), bounds),
            (self.addressLayer, CGFloat(112.0), bounds)
        ] {
            self.animateBand(layer, width: width, frame: frame, cardWidth: size.width + 8.0)
        }
    }

    private func animateBand(_ layer: SimpleGradientLayer, width: CGFloat, frame: CGRect, cardWidth: CGFloat) {
        guard frame.width > 0.0, frame.height > 0.0, let animationStartTime = self.animationStartTime else { return }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            return CGPoint(x: (x - 4.0 - frame.minX) / frame.width, y: (y - 4.0 - frame.minY) / frame.height)
        }
        let fromX = -0.6 * cardWidth
        let toX = 1.6 * cardWidth
        let duration = 1.46
        let passFraction = 0.96 / duration
        let ease = CAMediaTimingFunction(controlPoints: 1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0)
        var animations: [CAAnimation] = []
        for (keyPath, from, to) in [
            ("startPoint", point(fromX - width, 0.0), point(toX - width, 0.0)),
            ("endPoint", point(fromX + width, width * 0.7), point(toX + width, width * 0.7))
        ] {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = [NSValue(cgPoint: from), NSValue(cgPoint: to), NSValue(cgPoint: to)]
            animation.keyTimes = [0.0, NSNumber(value: passFraction), 1.0]
            animation.timingFunctions = [ease, CAMediaTimingFunction(name: .linear)]
            animation.duration = duration
            animations.append(animation)
        }
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.0, 0.0]
        opacity.keyTimes = [0.0, NSNumber(value: passFraction), 1.0]
        opacity.calculationMode = .discrete
        opacity.duration = duration
        animations.append(opacity)

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.beginTime = layer.convertTime(animationStartTime, from: nil)
        group.repeatCount = self.repeatAnimation ? .infinity : 0.0
        if !self.repeatAnimation, layer === self.surfaceLayer {
            group.completion = { [weak self] finished in
                if finished {
                    self?.completion?()
                }
            }
        }
        layer.add(group, forKey: "shimmer")
    }
}

public final class ChatMessageTransferBubbleContentNode: ChatMessageBubbleContentNode {
    private struct BackgroundRotationAnimation {
        let duration: CFTimeInterval
        let turns: CGFloat
        var start: (time: CFTimeInterval, offset: CGFloat)?
    }

    private let labelNode: TextNode
    private var labelBackgroundNode: WallpaperBubbleBackgroundNode?
    private let labelBackgroundMaskNode: ASImageNode
    private var linkHighlightingNode: LinkHighlightingNode?

    private let mediaContainerNode: ASDisplayNode
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let cardNode: ASDisplayNode
    private let cardBackgroundNode: ASImageNode
    private var cardBackgroundRotation: CGFloat = 0.0
    private var cardBackgroundMotion: (rotation: CGFloat, time: CFTimeInterval)?
    private var cardBackgroundDeviceMotion: Disposable?
    private var cardBackgroundRotationAnimation: BackgroundRotationAnimation?
    private var cardIcon = ComponentView<Empty>()
    private let amountNode: TextNode
    private let nameNode: TextNode
    private let addressNode: TextNode
    private let addressHighlightNode: TextNode
    private let addressShimmerMaskNode: TextNode
    private var shimmerView: TransferCardShimmerView?
    private var isHighlighted = false
    private var isPlayingHighlightShimmer = false
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
    private var ribbonGlintLayer: SimpleGradientLayer?
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

    public var scrollTiltProvider: ((CFTimeInterval) -> Float)? {
        didSet {
            (self.cardIcon.view as? InteractiveDiamondComponent.View)?.scrollTiltProvider = self.scrollTiltProvider
        }
    }

    override public var disablesClipping: Bool {
        return true
    }

    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if (oldValue != .none) != (self.visibility != .none) {
                (self.cardIcon.view as? InteractiveDiamondComponent.View)?.isRenderingEnabled = self.visibility != .none
                if self.visibility == .none {
                    self.stopCardBackgroundMotion()
                    self.finishCompletionAnimation()
                    self.isPlayingHighlightShimmer = false
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
        self.cardNode.clipsToBounds = true
        self.cardNode.cornerRadius = 20.0

        self.cardBackgroundNode = ASImageNode()
        self.cardBackgroundNode.isLayerBacked = true
        self.cardBackgroundNode.isUserInteractionEnabled = false
        self.cardBackgroundNode.isOpaque = true
        self.cardBackgroundNode.displaysAsynchronously = false
        self.cardBackgroundNode.displayWithoutProcessing = true
        self.cardBackgroundNode.contentMode = .scaleToFill
        self.cardBackgroundNode.image = UIImage(bundleImageName: "Wallet/CardChatGradient")

        self.amountNode = TextNode()
        self.amountNode.isUserInteractionEnabled = false
        self.amountNode.displaysAsynchronously = false

        self.nameNode = TextNode()
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.displaysAsynchronously = false

        self.addressNode = TextNode()
        self.addressNode.isUserInteractionEnabled = false
        self.addressNode.displaysAsynchronously = false

        self.addressHighlightNode = TextNode()
        self.addressHighlightNode.isUserInteractionEnabled = false
        self.addressHighlightNode.displaysAsynchronously = false
        self.addressHighlightNode.alpha = 0.06

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
            image: UIImage(bundleImageName: "Wallet/MessageRibbon"),
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
        self.ribbonTextMaskNode.image = UIImage(bundleImageName: "Wallet/MessageRibbon")

        super.init(lottieSettings: lottieSettings)

        self.cardNode.addSubnode(self.cardBackgroundNode)
        self.cardNode.addSubnode(self.amountNode)
        self.cardNode.addSubnode(self.nameNode)
        self.cardNode.addSubnode(self.addressHighlightNode)
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
        self.cardBackgroundDeviceMotion?.dispose()
        self.walletStateDisposable?.dispose()
    }

    private func stopCardBackgroundMotion() {
        self.cardBackgroundDeviceMotion?.dispose()
        self.cardBackgroundDeviceMotion = nil
        self.cardBackgroundRotationAnimation = nil
        self.cardBackgroundMotion = nil
    }

    private func updateCardBackgroundRotation(_ state: InteractiveDiamondComponent.MotionState?) {
        guard let state, self.visibility != .none,
              UIApplication.shared.applicationState == .active, !UIAccessibility.isReduceMotionEnabled,
              let window = self.cardIcon.view?.window else {
            self.stopCardBackgroundMotion()
            return
        }
        if self.cardBackgroundDeviceMotion == nil {
            self.cardBackgroundDeviceMotion = WalletCardBackgroundMotion.shared.subscribe()
            if self.cardBackgroundRotationAnimation == nil {
                self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(duration: 0.22, turns: 0.0)
            }
        }
        let deviceRotation = WalletCardBackgroundMotion.shared.rotation(
            at: CACurrentMediaTime(),
            orientation: window.windowScene?.interfaceOrientation ?? .portrait
        )

        let rotation: CGFloat
        if let transferEnergy = state.transferEnergy, !self.isIncomingTransfer, self.displayedTransferStatus == .pending {
            self.cardBackgroundRotationAnimation = nil
            defer {
                self.cardBackgroundMotion = (state.rotation, state.time)
            }
            guard let previous = self.cardBackgroundMotion, state.time >= previous.time else { return }
            let delta = state.rotation - previous.rotation
            let energy = min(1.0, max(0.0, transferEnergy))
            let step = atan2(sin(delta), cos(delta)) * 2.0 * (1.0 - 0.5 * energy)
                + 0.12 * CGFloat(state.time - previous.time)
            rotation = self.cardBackgroundRotation + step
        } else {
            self.cardBackgroundMotion = nil
            if var animation = self.cardBackgroundRotationAnimation {
                let start: (time: CFTimeInterval, offset: CGFloat)
                if let current = animation.start {
                    start = current
                } else {
                    let delta = self.cardBackgroundRotation - deviceRotation
                    start = (state.time, atan2(sin(delta), cos(delta)) - animation.turns * 2.0 * .pi)
                    animation.start = start
                }
                let progress = CGFloat(min(1.0, max(0.0, (state.time - start.time) / animation.duration)))
                let remaining = 1.0 - progress
                rotation = deviceRotation + start.offset * remaining * remaining * remaining
                self.cardBackgroundRotationAnimation = progress < 1.0 ? animation : nil
            } else {
                rotation = deviceRotation
            }
        }
        let normalizedRotation = rotation.truncatingRemainder(dividingBy: 2.0 * .pi)
        guard self.cardBackgroundRotation != normalizedRotation else { return }
        self.cardBackgroundRotation = normalizedRotation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.cardBackgroundNode.transform = CATransform3DMakeRotation(self.cardBackgroundRotation, 0.0, 0.0, 1.0)
        CATransaction.commit()
    }

    private func updateDiamondRefraction() {
        guard let diamond = self.cardIcon.view as? InteractiveDiamondComponent.View else { return }
        guard diamond.isExpanded else {
            diamond.updateRefractionSource(nil)
            return
        }

        let sourceRect = self.amountNode.frame.insetBy(dx: -2.0, dy: -2.0).integral
        let scale = UIScreen.main.scale
        let width = Int(ceil(sourceRect.width * scale))
        let height = Int(ceil(sourceRect.height * scale))
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
              let bytes = context.data else {
            diamond.updateRefractionSource(nil)
            return
        }
        context.clear(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        context.translateBy(x: 0.0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: self.amountNode.frame.minX - sourceRect.minX, y: self.amountNode.frame.minY - sourceRect.minY)
        UIGraphicsPushContext(context)
        TextNode.draw(self.amountNode.bounds,
            withParameters: TextNode.DrawingParameters(cachedLayout: self.amountNode.cachedLayout, renderContentTypes: .all),
            isCancelled: { false }, isRasterizing: true)
        UIGraphicsPopContext()

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let texture = MetalEngine.shared.device.makeTexture(descriptor: descriptor) else {
            diamond.updateRefractionSource(nil)
            return
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: context.bytesPerRow)
        let rect = self.cardNode.view.convert(sourceRect, to: diamond)
            .offsetBy(dx: -diamond.bounds.midX, dy: -diamond.bounds.midY)
        diamond.updateRefractionSource(InteractiveDiamondComponent.RefractionSource(
            texture: texture, uv: SIMD4(0.0, 0.0, 1.0, 1.0), rect: rect, preservesColors: true
        ))
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
            self.isHighlighted = false
            self.isPlayingHighlightShimmer = false
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
        if self.isSendingTransfer {
            self.cardBackgroundRotationAnimation = nil
        }
        (self.cardIcon.view as? InteractiveDiamondComponent.View)?.isUserInteractionEnabled = !self.isSendingTransfer
        if previousStatus == status {
            (self.cardIcon.view as? InteractiveDiamondComponent.View)?.updateTransferState(isSending: self.isSendingTransfer, animateCompletion: false)
            if status == .pending {
                self.updateShimmer(animated: false)
            }
            return
        }
        self.finishCompletionAnimation()
        self.updateShimmer(animated: animated && previousStatus != nil)
        let animateCompletion = !self.isIncomingTransfer && status == .completed && previousStatus != nil && animated && self.visibility != .none
        if status == .completed {
            self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(
                duration: animateCompletion ? 1.8 : 0.22,
                turns: animateCompletion ? 2.0 : 0.0
            )
        }
        (self.cardIcon.view as? InteractiveDiamondComponent.View)?.updateTransferState(isSending: self.isSendingTransfer, animateCompletion: animateCompletion)
        if animateCompletion {
            self.playCompletionHaptics()
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
        let displayShimmer = (self.displayedTransferStatus == .pending || self.isPlayingHighlightShimmer) && self.visibility != .none
        if displayShimmer {
            let repeatAnimation = !self.isPlayingHighlightShimmer
            let shimmerView: TransferCardShimmerView
            if let current = self.shimmerView, current.repeatAnimation == repeatAnimation {
                shimmerView = current
            } else {
                self.shimmerView?.removeFromSuperview()
                shimmerView = TransferCardShimmerView(addressMask: self.addressShimmerMaskNode.view, repeatAnimation: repeatAnimation)
                self.shimmerView = shimmerView
                self.cardNode.view.addSubview(shimmerView)
                if !repeatAnimation {
                    self.animateHighlightBump()
                    shimmerView.completion = { [weak self, weak shimmerView] in
                        guard let self, let shimmerView, self.shimmerView === shimmerView else {
                            return
                        }
                        self.isPlayingHighlightShimmer = false
                        self.shimmerView = nil
                        shimmerView.removeFromSuperview()
                        self.updateShimmer(animated: false)
                    }
                }
            }
            if let iconView = self.cardIcon.view, iconView.superview === self.cardNode.view {
                self.cardNode.view.bringSubviewToFront(iconView)
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
                let fadeValues = (0 ... 36).map { NSNumber(value: pow(1.0 - Double($0) / 36.0, 2.2)) }
                shimmerView.layer.animateKeyframes(values: fadeValues, duration: 0.3, keyPath: "opacity", completion: { [weak self, weak shimmerView] finished in
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

    private func animateHighlightBump() {
        guard self.visibility != .none, UIApplication.shared.applicationState == .active,
              !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let delay = 0.18
        let durationFactor = 1.7
        let duration = 0.9 * durationFactor
        let frameCount = Int(ceil(duration * 120.0))
        var values: [NSNumber] = [1.0]
        var keyTimes: [NSNumber] = [0.0]
        for index in 0 ... frameCount {
            let progress = Double(index) / Double(frameCount)
            let time = duration * progress / durationFactor
            let bump = index == frameCount ? 0.0 : sin(2.0 * .pi * 1.6 * time) * exp(-time / 0.2)
            values.append(NSNumber(value: 1.0 + 0.06 * bump))
            keyTimes.append(NSNumber(value: (delay + duration * progress) / (delay + duration)))
        }
        self.mediaContainerNode.layer.animateKeyframes(
            values: values,
            keyTimes: keyTimes,
            duration: delay + duration,
            keyPath: "transform.scale"
        )
        Queue.mainQueue().after(delay, { [weak self, weak shimmerView = self.shimmerView] in
            guard let self, let shimmerView, self.shimmerView === shimmerView, self.visibility != .none else {
                return
            }
            (self.cardIcon.view as? InteractiveDiamondComponent.View)?.pushFromBelow(strength: 1.5)
        })
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
        self.ribbonGlintLayer?.removeAllAnimations()
        self.ribbonGlintLayer?.removeFromSuperlayer()
        self.ribbonGlintLayer = nil
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
            color: UIColor(rgb: self.isIncomingTransfer ? 0x42b0ff : 0x00cf00)
        )
        self.updateSendingClockAnimation()
    }

    private func playCompletionHaptics() {
        guard UIApplication.shared.applicationState == .active else { return }
        Haptics.strong()
        let animationId = self.completionAnimationId
        for (delay, intensity) in [(0.13, CGFloat(0.7)), (0.3, CGFloat(0.45))] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.completionAnimationId == animationId,
                      self.visibility != .none, self.displayedTransferStatus == .completed,
                      UIApplication.shared.applicationState == .active else { return }
                Haptics.hit(intensity)
            }
        }
    }

    private func animateRibbonGlint() {
        let frame = self.ribbonBackgroundNode.frame
        guard frame.width > 0.0, frame.height > 0.0 else {
            return
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            return CGPoint(x: (x - frame.minX) / frame.width, y: (y - frame.minY) / frame.height)
        }

        let glintLayer = SimpleGradientLayer()
        glintLayer.frame = frame
        glintLayer.colors = [UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: 0.7).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
        glintLayer.locations = [0.0, 0.5, 1.0]
        glintLayer.opacity = 0.0
        glintLayer.compositingFilter = "plusL"

        let maskLayer = SimpleShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: frame.size)
        maskLayer.contentsScale = UIScreenScale
        maskLayer.fillColor = UIColor.white.cgColor
        maskLayer.path = TransferCardRibbonGeometry.path
        glintLayer.mask = maskLayer
        self.ribbonGlintLayer = glintLayer
        self.mediaContainerNode.layer.insertSublayer(glintLayer, above: self.ribbonBackgroundNode.layer)

        let delay = 0.6
        let duration = 0.55
        glintLayer.startPoint = point(226.0, 0.0)
        glintLayer.endPoint = point(254.0, 12.0)
        for (keyPath, from, to) in [
            ("startPoint", point(136.0, 0.0), glintLayer.startPoint),
            ("endPoint", point(164.0, 12.0), glintLayer.endPoint)
        ] {
            glintLayer.animate(from: NSValue(cgPoint: from), to: NSValue(cgPoint: to), keyPath: keyPath, timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration, delay: delay)
        }

        let frameCount = Int(ceil(duration * 120.0))
        var values: [NSNumber] = [0.0]
        var keyTimes: [NSNumber] = [0.0]
        for index in 0 ... frameCount {
            let progress = Double(index) / Double(frameCount)
            values.append(NSNumber(value: index == frameCount ? 0.0 : sin(.pi * progress)))
            keyTimes.append(NSNumber(value: (delay + duration * progress) / (delay + duration)))
        }
        glintLayer.animateKeyframes(values: values, keyTimes: keyTimes, duration: delay + duration, keyPath: "opacity")
    }

    private func animateCompletion() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let animationId = self.completionAnimationId
        let ribbonFrame = self.ribbonBackgroundNode.frame
        let clockCenter = CGPoint(
            x: self.cardNode.frame.minX + self.sendingClockNode.position.x - ribbonFrame.minX,
            y: self.cardNode.frame.minY + self.sendingClockNode.position.y - ribbonFrame.minY
        )
        let finalPath = TransferCardRibbonGeometry.path
        let ribbonCenter = TransferCardRibbonGeometry.center
        let overshootOffset = -0.02 * (ribbonCenter.x + ribbonCenter.y)
        var overshootTransform = CGAffineTransform(a: 1.02, b: 0.02, c: 0.02, d: 1.02, tx: overshootOffset, ty: overshootOffset)
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
        self.animateRibbonGlint()

        let bounceDuration = 1.2
        let bounceFrameCount = Int(bounceDuration * 120.0)
        let bounceValues = (0 ... bounceFrameCount).map { index -> NSNumber in
            let time = bounceDuration * Double(index) / Double(bounceFrameCount)
            let bounce = index == bounceFrameCount ? 0.0 : -sin(2.0 * Double.pi * 2.0 * time) * exp(-time / 0.25)
            return NSNumber(value: 1.0 + 0.045 * bounce)
        }
        self.mediaContainerNode.layer.animateKeyframes(
            values: bounceValues,
            duration: bounceDuration,
            keyPath: "transform.scale",
            timingFunction: CAMediaTimingFunctionName.linear.rawValue,
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
        let makeAddressHighlightLayout = TextNode.asyncLayout(self.addressHighlightNode)
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
                let hasEncryptedCaption = commentEncrypted

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
                    weight: .bold
                )
                let fractionalAmountFont = Font.with(
                    size: 14.0,
                    design: .round,
                    weight: .bold
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
                let addressLayoutArguments = TextNodeLayoutArguments(
                    attributedString: NSAttributedString(
                        string: addressGroups.joined(separator: " "),
                        font: Font.with(size: 10.0, design: .monospace, weight: .medium),
                        textColor: UIColor.black.withAlphaComponent(0.3),
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
                )
                let (addressLayout, addressApply) = makeAddressLayout(addressLayoutArguments)
                let whiteAddressLayoutArguments = addressLayoutArguments.withAttributedString(
                    NSAttributedString(
                        string: addressGroups.joined(separator: " "),
                        font: Font.with(size: 10.0, design: .monospace, weight: .medium),
                        textColor: .white,
                        paragraphAlignment: .center
                    )
                )
                let (_, addressHighlightApply) = makeAddressHighlightLayout(whiteAddressLayoutArguments)
                let (_, addressShimmerMaskApply) = makeAddressShimmerMaskLayout(whiteAddressLayoutArguments)

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
                            self.stopCardBackgroundMotion()
                            (self.cardIcon.view as? InteractiveDiamondComponent.View)?.isRenderingEnabled = false
                            self.cardIcon.view?.removeFromSuperview()
                            self.cardIcon = ComponentView<Empty>()
                            self.cardBackgroundRotation = 0.0
                            self.cardBackgroundMotion = nil
                            self.cardBackgroundNode.transform = CATransform3DIdentity
                        }
                        self.item = item
                        self.isIncomingTransfer = isIncoming

                        let refractionContentChanged = self.amountNode.cachedLayout !== amountLayout
                        let _ = labelApply()
                        let _ = amountApply()
                        let _ = nameApply()
                        let _ = addressApply()
                        let _ = addressHighlightApply()
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
                        self.cardBackgroundNode.bounds = CGRect(origin: .zero, size: CGSize(width: 380.0, height: 295.0))
                        self.cardBackgroundNode.position = CGPoint(x: cardSize.width * 0.5, y: cardSize.height * 0.5)

                        let clockSize = CGSize(width: 14.0, height: 14.0)
                        let clockInset = 12.0 + (1.0 - UIScreenPixel)
                        self.sendingClockNode.frame = CGRect(origin: CGPoint(x: cardSize.width - clockSize.width - clockInset, y: clockInset), size: clockSize)
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
                            let clockColor = UIColor.white
                            self.clockFrameNode.image = generateTintedImage(image: graphics.clockMediaFrameImage, color: clockColor)
                            self.clockMinNode.image = generateTintedImage(image: graphics.clockMediaMinImage, color: clockColor)
                        }

                        let iconSize = CGSize(width: 38.0, height: 38.0)
                        let iconFrame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - iconSize.width) * 0.5), y: 16.0),
                            size: iconSize
                        )
                        let animationSize = CGSize(width: 64.0, height: 64.0)
                        let _ = self.cardIcon.update(
                            transition: .immediate,
                            component: AnyComponent(InteractiveDiamondComponent(
                                size: animationSize,
                                diamondWidth: iconSize.width,
                                isVisible: self.visibility != .none,
                                theme: item.presentationData.theme.theme,
                                appearance: .cool,
                                expansionStyle: .downward,
                                tapToSpin: true
                            )),
                            environment: {},
                            containerSize: animationSize
                        )
                        if let iconView = self.cardIcon.view as? InteractiveDiamondComponent.View {
                            iconView.scrollTiltProvider = self.scrollTiltProvider
                            if iconView.superview == nil {
                                self.cardNode.view.addSubview(iconView)
                                iconView.onExpansionChanged = { [weak self] isExpanded in
                                    guard let self else { return }
                                    if isExpanded {
                                        if self.cardBackgroundRotationAnimation != nil {
                                            self.cardBackgroundRotationAnimation = BackgroundRotationAnimation(duration: 0.22, turns: 0.0)
                                        }
                                        self.cardBackgroundMotion = nil
                                    }
                                    self.updateDiamondRefraction()
                                }
                                iconView.onMotionUpdated = { [weak self] state in
                                    self?.updateCardBackgroundRotation(state)
                                }
                            }
                            iconView.frame = CGRect(
                                x: iconFrame.midX - animationSize.width * 0.5,
                                y: iconFrame.midY - animationSize.height * 0.5,
                                width: animationSize.width,
                                height: animationSize.height
                            )
                        }
                        self.amountNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - amountLayout.size.width) * 0.5), y: 62.0),
                            size: amountLayout.size
                        )
                        self.nameNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - nameLayout.size.width) * 0.5), y: 97.0),
                            size: nameLayout.size
                        )
                        if refractionContentChanged, (self.cardIcon.view as? InteractiveDiamondComponent.View)?.isExpanded == true {
                            self.updateDiamondRefraction()
                        }
                        self.addressNode.frame = CGRect(
                            origin: CGPoint(x: floorToScreenPixels((cardSize.width - addressLayout.size.width) * 0.5), y: 114.0),
                            size: addressLayout.size
                        )
                        self.addressHighlightNode.frame = self.addressNode.frame.offsetBy(dx: 0.0, dy: 1.0)
                        self.addressShimmerMaskNode.frame = self.addressNode.frame

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
                        let ribbonCenter = TransferCardRibbonGeometry.center
                        let ribbonTextPosition = CGPoint(x: ribbonCenter.x, y: ribbonCenter.y + 1.0)
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

    override public func updateHighlightedState(animated: Bool) -> Bool {
        guard let item = self.item else {
            return false
        }
        let highlighted = item.controllerInteraction.highlightedState?.messageStableId == item.message.stableId
        if self.isHighlighted != highlighted {
            self.isHighlighted = highlighted
            if highlighted {
                self.isPlayingHighlightShimmer = true
                self.shimmerView?.removeFromSuperview()
                self.shimmerView = nil
                self.updateShimmer(animated: false)
            }
        }
        return highlighted
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
        if let iconView = self.cardIcon.view as? InteractiveDiamondComponent.View,
           iconView.isUserInteractionEnabled,
           iconView.point(inside: iconView.convert(point, from: self.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
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
        if gesture == .tap, let captionDustNode = self.captionDustNode, captionDustNode.frame.contains(mediaPoint) {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                guard let self, let item = self.item else {
                    return
                }
                let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default, decryptWalletComment: true))
            }))
        }
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
