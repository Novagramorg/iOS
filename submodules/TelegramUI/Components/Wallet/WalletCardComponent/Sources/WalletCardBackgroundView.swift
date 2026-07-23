import Foundation
import UIKit
import CoreMotion

private let walletCardBackgroundReferenceSize = CGSize(width: 336.0, height: 205.0)

private struct WalletCardTilt {
    var x: CGFloat
    var y: CGFloat

    static let zero = WalletCardTilt(x: 0.0, y: 0.0)
}

#if targetEnvironment(simulator)
private final class WalletCardSimulatorDisplayLinkTarget: NSObject {
    private let update: (CADisplayLink) -> Void

    init(update: @escaping (CADisplayLink) -> Void) {
        self.update = update
    }

    @objc func displayLinkUpdated(_ displayLink: CADisplayLink) {
        self.update(displayLink)
    }
}
#endif

private enum WalletCardEffectCache {
    static let stepCount = 200

    static let shineLocations: [[NSNumber]] = (0 ... stepCount).map { index in
        let magnitude = CGFloat(index) / CGFloat(stepCount) * 2.0
        return walletCardConicLocations(spread: 0.11 + magnitude * 0.06)
    }

    static let starLocations: [[NSNumber]] = (0 ... stepCount).map { index in
        let magnitude = CGFloat(index) / CGFloat(stepCount) * 2.0
        return walletCardConicLocations(spread: 0.16 + magnitude * 0.06)
    }

    static let shineColors: [[CGColor]] = (0 ... stepCount).map { index in
        let tiltY = -1.0 + CGFloat(index) / CGFloat(stepCount) * 2.0
        let color = walletCardShineColor(tiltY: tiltY).cgColor
        let transparent = color.copy(alpha: 0.0) ?? color
        return [
            transparent,
            transparent,
            color,
            transparent,
            transparent,
            color,
            transparent,
            transparent
        ]
    }

    static let starColors: [CGColor] = {
        let transparent = UIColor.clear.cgColor
        let color = UIColor.white.cgColor
        return [
            transparent,
            transparent,
            color,
            transparent,
            transparent,
            color,
            transparent,
            transparent
        ]
    }()
}

private final class WalletCardBlurView: UIVisualEffectView {
    private var blurRadius: CGFloat = 10.0
    private var isAssigningEffect = false
    private var isConfiguringEffect = false
    private var didFailConfiguration = false

    override var effect: UIVisualEffect? {
        get {
            return super.effect
        }
        set {
            self.isAssigningEffect = true
            super.effect = newValue
            self.isAssigningEffect = false
            if newValue != nil {
                self.configureEffect(disableOnFailure: true)
            }
        }
    }

    override init(effect: UIVisualEffect?) {
        super.init(effect: nil)

        self.isUserInteractionEnabled = false
        if effect != nil {
            self.effect = effect
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if !self.isAssigningEffect {
            self.configureEffect(disableOnFailure: false)
        }
    }

    func update(blurRadius: CGFloat, isEnabled: Bool) {
        let radiusUpdated = abs(self.blurRadius - blurRadius) > .ulpOfOne
        self.blurRadius = blurRadius

        if isEnabled {
            if super.effect == nil && !self.didFailConfiguration {
                self.effect = UIBlurEffect(style: .light)
            } else if radiusUpdated {
                self.configureEffect(disableOnFailure: true)
            }
        } else {
            super.effect = nil
        }
    }

    private func configureEffect(disableOnFailure: Bool) {
        guard !self.isConfiguringEffect, super.effect != nil else {
            return
        }
        self.isConfiguringEffect = true
        defer {
            self.isConfiguringEffect = false
        }

        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }

        guard let backdropLayer = self.layer.sublayers?.first, let filters = backdropLayer.filters else {
            if disableOnFailure {
                self.didFailConfiguration = true
                super.effect = nil
            }
            return
        }

        backdropLayer.backgroundColor = nil
        backdropLayer.isOpaque = false

        var gaussianBlurFilter: NSObject?
        for filter in filters {
            guard let filter = filter as? NSObject else {
                continue
            }
            if String(describing: filter) == "gaussianBlur" {
                gaussianBlurFilter = filter
                break
            }
        }

        guard let gaussianBlurFilter else {
            if disableOnFailure {
                self.didFailConfiguration = true
                super.effect = nil
            }
            return
        }

        gaussianBlurFilter.setValue(self.blurRadius as NSNumber, forKey: "inputRadius")
        backdropLayer.filters = [gaussianBlurFilter]
        self.didFailConfiguration = false
    }
}

private struct WalletCardTextureKey: Hashable {
    let width: Int
    let height: Int
}

private final class WalletCardTextureLayer: CALayer {
    private static var imageCache: [WalletCardTextureKey: CGImage] = [:]
    private var currentKey: WalletCardTextureKey?

    override init() {
        super.init()

        self.isOpaque = true
        self.contentsGravity = .resize
        self.magnificationFilter = .linear
        self.minificationFilter = .linear
        self.compositingFilter = "overlayBlendMode"
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, displayScale: CGFloat) {
        guard size.width > 0.0, size.height > 0.0 else {
            self.currentKey = nil
            self.contents = nil
            return
        }

        let renderScale = max(1.0, min(displayScale, 2.0))
        let pixelWidth = max(1, Int(ceil(size.width * renderScale)))
        let pixelHeight = max(1, Int(ceil(size.height * renderScale)))
        let key = WalletCardTextureKey(width: pixelWidth, height: pixelHeight)
        guard self.currentKey != key else {
            return
        }
        self.currentKey = key

        let image: CGImage
        if let cachedImage = WalletCardTextureLayer.imageCache[key] {
            image = cachedImage
        } else if let generatedImage = generateWalletCardTexture(width: pixelWidth, height: pixelHeight) {
            image = generatedImage
            if WalletCardTextureLayer.imageCache.count >= 8, let firstKey = WalletCardTextureLayer.imageCache.keys.first {
                WalletCardTextureLayer.imageCache.removeValue(forKey: firstKey)
            }
            WalletCardTextureLayer.imageCache[key] = generatedImage
        } else {
            self.contents = nil
            return
        }

        self.contentsScale = renderScale
        self.contents = image
    }
}

private final class WalletCardTextureView: UIView {
    override class var layerClass: AnyClass {
        return WalletCardTextureLayer.self
    }

    private var textureLayer: WalletCardTextureLayer {
        return self.layer as! WalletCardTextureLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, displayScale: CGFloat) {
        self.textureLayer.update(size: size, displayScale: displayScale)
    }
}

final class WalletCardBackgroundView: UIView {
    private static let rawStars: [CGPoint] = [
        CGPoint(x: 14.0, y: 10.0),
        CGPoint(x: 70.0, y: 26.0),
        CGPoint(x: 126.0, y: 14.0),
        CGPoint(x: 188.0, y: 28.0),
        CGPoint(x: 248.0, y: 14.0),
        CGPoint(x: 22.0, y: 50.0),
        CGPoint(x: 120.0, y: 48.0),
        CGPoint(x: 212.0, y: 50.0),
        CGPoint(x: 262.0, y: 50.0),
        CGPoint(x: 222.0, y: 76.0),
        CGPoint(x: 56.0, y: 144.0),
        CGPoint(x: 110.0, y: 156.0),
        CGPoint(x: 156.0, y: 144.0),
        CGPoint(x: 188.0, y: 160.0),
        CGPoint(x: 156.0, y: 196.0),
        CGPoint(x: 188.0, y: 196.0)
    ]

    private let shineView: UIView
    private let shineLayer: CAGradientLayer
    private let blurView: WalletCardBlurView
    private let blurOverlayView: UIView
    private let textureView: WalletCardTextureView
    private let starsView: UIView
    private let starsMaskLayer: CAGradientLayer
    private let starLayers: [CAShapeLayer]
    private let innerShadowLayer: CAShapeLayer

    private let motionManager = CMMotionManager()
    private var notificationObservers: [NSObjectProtocol] = []
    private var isMotionActive = false
    private var areStarAnimationsActive = false
    private var currentTilt = WalletCardTilt.zero
    private var currentSize = CGSize.zero
    private var safeZones: [CGRect] = []
    private var starAnimationOrdinals: [Int]
    private var currentMagnitudeEffectIndex = -1
    private var currentColorEffectIndex = -1
    #if targetEnvironment(simulator)
    private var demoDisplayLinkTarget: WalletCardSimulatorDisplayLinkTarget?
    private var demoDisplayLink: CADisplayLink?
    private var demoStartTimestamp: CFTimeInterval?
    #endif

    override init(frame: CGRect) {
        self.shineView = UIView()
        self.shineLayer = CAGradientLayer()
        self.blurView = WalletCardBlurView(effect: nil)
        self.blurOverlayView = UIView()
        self.textureView = WalletCardTextureView()
        self.starsView = UIView()
        self.starsMaskLayer = CAGradientLayer()
        self.starLayers = WalletCardBackgroundView.rawStars.map { _ in CAShapeLayer() }
        self.innerShadowLayer = CAShapeLayer()
        self.starAnimationOrdinals = Array(repeating: -1, count: WalletCardBackgroundView.rawStars.count)

        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.backgroundColor = UIColor(red: 0.0, green: 136.0 / 255.0, blue: 1.0, alpha: 1.0)
        self.clipsToBounds = true

        self.shineView.isUserInteractionEnabled = false
        self.shineLayer.type = .conic
        self.shineLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.shineLayer.opacity = 0.75
        self.shineLayer.compositingFilter = "overlayBlendMode" //"softLightBlendMode"// "screenBlendMode"
        self.shineView.layer.addSublayer(self.shineLayer)
        self.addSubview(self.shineView)

        self.addSubview(self.blurView)

        self.blurOverlayView.isUserInteractionEnabled = false
        self.blurOverlayView.backgroundColor = UIColor.white.withAlphaComponent(0.01)
        self.addSubview(self.blurOverlayView)

        self.addSubview(self.textureView)

        self.starsView.isUserInteractionEnabled = false
        self.starsView.layer.compositingFilter = "softLightBlendMode"
        self.starsMaskLayer.type = .conic
        self.starsMaskLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.starsMaskLayer.colors = WalletCardEffectCache.starColors
        self.starsView.layer.mask = self.starsMaskLayer
        for starLayer in self.starLayers {
            starLayer.fillColor = UIColor.white.withAlphaComponent(0.5).cgColor
            self.starsView.layer.addSublayer(starLayer)
        }
        self.addSubview(self.starsView)

        self.innerShadowLayer.fillRule = .evenOdd
        self.innerShadowLayer.fillColor = UIColor.black.cgColor
        self.innerShadowLayer.shadowColor = UIColor.black.cgColor
        self.innerShadowLayer.shadowOpacity = 0.16
        self.innerShadowLayer.masksToBounds = true
        self.layer.addSublayer(self.innerShadowLayer)

        let notificationCenter = NotificationCenter.default
        self.notificationObservers.append(notificationCenter.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.updateActivity()
            }
        ))
        self.notificationObservers.append(notificationCenter.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.updateBlur()
            }
        ))
        self.notificationObservers.append(notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.updateActivity()
            }
        ))
        self.notificationObservers.append(notificationCenter.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.updateActivity()
            }
        ))

        self.updateEffects(tilt: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        for observer in self.notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        self.motionManager.stopDeviceMotionUpdates()
        #if targetEnvironment(simulator)
        self.demoDisplayLink?.invalidate()
        #endif
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.currentSize.width > 0.0, self.currentSize.height > 0.0 {
            self.textureView.update(size: self.currentSize, displayScale: self.textureDisplayScale)
        }
        self.updateActivity()
    }

    private var textureDisplayScale: CGFloat {
        let displayScale = self.window?.windowScene?.screen.scale ?? self.traitCollection.displayScale
        return displayScale > 0.0 ? displayScale : 2.0
    }

    func update(size: CGSize, safeZones: [CGRect]) {
        self.currentSize = size
        self.safeZones = safeZones

        let bounds = CGRect(origin: .zero, size: size)
        let scaleX = size.width / walletCardBackgroundReferenceSize.width
        let scaleY = size.height / walletCardBackgroundReferenceSize.height
        let cornerRadius = 20.0 * scaleX

        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        self.layer.cornerRadius = cornerRadius

        self.shineView.frame = bounds
        let shineSide = 349.5 * scaleX
        self.shineLayer.bounds = CGRect(x: 0.0, y: 0.0, width: shineSide, height: shineSide)
        self.shineLayer.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        self.shineLayer.setAffineTransform(CGAffineTransform(scaleX: 1.0, y: 1.65))

        self.blurView.frame = bounds
        self.blurOverlayView.frame = bounds
        self.textureView.frame = bounds
        self.textureView.update(size: size, displayScale: self.textureDisplayScale)

        self.starsView.frame = bounds
        self.starsMaskLayer.frame = bounds
        self.layoutStars(scaleX: scaleX, scaleY: scaleY)

        self.innerShadowLayer.frame = bounds
        self.updateInnerShadowPath(bounds: bounds, cornerRadius: cornerRadius, scale: scaleX)

        self.updateBlur()
        self.updateEffects(tilt: self.currentTilt)
    }

    private func updateBlur() {
        let scale = self.currentSize.width / walletCardBackgroundReferenceSize.width
        self.blurView.update(
            blurRadius: 10.0 * scale,
            isEnabled: !UIAccessibility.isReduceTransparencyEnabled && self.currentSize.width > 0.0
        )
    }

    private func updateActivity() {
        let isWindowActive: Bool
        if let windowScene = self.window?.windowScene {
            isWindowActive = windowScene.activationState == .foregroundActive
        } else {
            isWindowActive = UIApplication.shared.applicationState == .active
        }
        let shouldAnimate = self.window != nil
            && self.window?.isHidden == false
            && isWindowActive
            && !UIAccessibility.isReduceMotionEnabled

        self.setStarAnimationsEnabled(shouldAnimate)

        if shouldAnimate && self.motionManager.isDeviceMotionAvailable {
            #if targetEnvironment(simulator)
            self.setSimulatorTiltEnabled(false)
            #endif
            self.startMotionUpdates()
        } else {
            #if targetEnvironment(simulator)
            self.stopMotionUpdates(resetTilt: false)
            self.setSimulatorTiltEnabled(shouldAnimate && !self.motionManager.isDeviceMotionAvailable)
            #else
            self.stopMotionUpdates(resetTilt: true)
            #endif
        }
    }

    #if targetEnvironment(simulator)
    private func setSimulatorTiltEnabled(_ enabled: Bool) {
        if enabled {
            guard self.demoDisplayLink == nil else {
                return
            }
            self.demoStartTimestamp = nil
            let displayLinkTarget = WalletCardSimulatorDisplayLinkTarget(update: { [weak self] displayLink in
                self?.updateSimulatorTilt(timestamp: displayLink.timestamp)
            })
            let displayLink = CADisplayLink(target: displayLinkTarget, selector: #selector(WalletCardSimulatorDisplayLinkTarget.displayLinkUpdated(_:)))
            displayLink.preferredFramesPerSecond = 60
            displayLink.add(to: .main, forMode: .common)
            self.demoDisplayLinkTarget = displayLinkTarget
            self.demoDisplayLink = displayLink
        } else {
            let wasActive = self.demoDisplayLink != nil
            self.demoDisplayLink?.invalidate()
            self.demoDisplayLink = nil
            self.demoDisplayLinkTarget = nil
            self.demoStartTimestamp = nil
            if wasActive && (self.currentTilt.x != 0.0 || self.currentTilt.y != 0.0) {
                self.currentTilt = .zero
                self.updateEffects(tilt: .zero)
            }
        }
    }

    private func updateSimulatorTilt(timestamp: CFTimeInterval) {
        if self.demoStartTimestamp == nil {
            self.demoStartTimestamp = timestamp
        }
        let elapsed = timestamp - (self.demoStartTimestamp ?? timestamp)
        let animationTime = elapsed * 1.5
        let target = WalletCardTilt(
            x: CGFloat(sin(animationTime * 0.47) * 0.62 + sin(animationTime * 1.13 + 0.8) * 0.1),
            y: CGFloat(sin(animationTime * 0.39 + 1.4) * 0.48 + sin(animationTime * 0.83) * 0.08)
        )
        self.applyTiltTarget(target)
    }
    #endif

    private func startMotionUpdates() {
        guard !self.isMotionActive else {
            return
        }
        self.isMotionActive = true
        self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        self.motionManager.startDeviceMotionUpdates(to: .main, withHandler: { [weak self] motion, _ in
            guard let self, let motion else {
                return
            }

            var x = CGFloat(motion.attitude.roll)
            var y = CGFloat(motion.attitude.pitch)
            if let orientation = self.window?.windowScene?.interfaceOrientation {
                switch orientation {
                case .portraitUpsideDown:
                    x = -x
                    y = -y
                case .landscapeLeft:
                    let previousX = x
                    x = -y
                    y = previousX
                case .landscapeRight:
                    let previousX = x
                    x = y
                    y = -previousX
                default:
                    break
                }
            }

            let maxAngle = CGFloat.pi / 4.0
            let target = WalletCardTilt(
                x: max(-1.0, min(1.0, x / maxAngle)),
                y: max(-1.0, min(1.0, y / maxAngle))
            )
            self.applyTiltTarget(target)
        })
    }

    private func applyTiltTarget(_ target: WalletCardTilt) {
        self.currentTilt.x += (target.x - self.currentTilt.x) * 0.15
        self.currentTilt.y += (target.y - self.currentTilt.y) * 0.15
        self.updateEffects(tilt: self.currentTilt)
    }

    private func stopMotionUpdates(resetTilt: Bool) {
        if self.isMotionActive {
            self.isMotionActive = false
            self.motionManager.stopDeviceMotionUpdates()
        }
        if resetTilt && (self.currentTilt.x != 0.0 || self.currentTilt.y != 0.0) {
            self.currentTilt = .zero
            self.updateEffects(tilt: .zero)
        }
    }

    private func setStarAnimationsEnabled(_ enabled: Bool) {
        guard self.areStarAnimationsActive != enabled else {
            return
        }
        self.areStarAnimationsActive = enabled

        self.updateStarAnimations()
    }

    private func updateStarAnimations() {
        let mediaTime = CACurrentMediaTime()
        for index in self.starLayers.indices {
            let starLayer = self.starLayers[index]
            starLayer.removeAnimation(forKey: "twinkle")
            let ordinal = self.starAnimationOrdinals[index]
            if self.areStarAnimationsActive && ordinal >= 0 {
                let rawDuration = 4.2 + (Double(ordinal) * 0.41).truncatingRemainder(dividingBy: 1.0) * 2.6
                let rawDelay = (Double(ordinal) * 0.73).truncatingRemainder(dividingBy: rawDuration)
                let duration = (rawDuration * 100.0).rounded() / 100.0
                let delay = (rawDelay * 100.0).rounded() / 100.0
                let animation = CABasicAnimation(keyPath: "transform.scale")
                animation.fromValue = 0.92
                animation.toValue = 1.08
                animation.duration = duration * 0.5
                animation.beginTime = mediaTime - delay
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.isRemovedOnCompletion = false
                starLayer.add(animation, forKey: "twinkle")
            } else {
                starLayer.transform = CATransform3DIdentity
            }
        }
    }

    private func layoutStars(scaleX: CGFloat, scaleY: CGFloat) {
        let safeZonePaddingX = 8.0 * scaleX
        let safeZonePaddingY = 8.0 * scaleY
        let expandedSafeZones = self.safeZones.map { safeZone in
            return safeZone.insetBy(dx: -safeZonePaddingX, dy: -safeZonePaddingY)
        }

        var visibleOrdinal = 0
        var animationsChanged = false
        for index in WalletCardBackgroundView.rawStars.indices {
            let rawPosition = WalletCardBackgroundView.rawStars[index]
            let position = CGPoint(x: rawPosition.x * scaleX, y: rawPosition.y * scaleY)
            let starSize = walletCardStarSize(x: rawPosition.x, y: rawPosition.y)
            let halfExtentX = starSize * scaleX
            let halfExtentY = starSize * scaleY
            let isHidden = expandedSafeZones.contains(where: { $0.contains(position) })
            let animationOrdinal = isHidden ? -1 : visibleOrdinal
            if !isHidden {
                visibleOrdinal += 1
            }
            if self.starAnimationOrdinals[index] != animationOrdinal {
                self.starAnimationOrdinals[index] = animationOrdinal
                animationsChanged = true
            }
            let layer = self.starLayers[index]
            layer.bounds = CGRect(x: 0.0, y: 0.0, width: halfExtentX * 2.0, height: halfExtentY * 2.0)
            layer.position = position
            layer.path = walletCardSparklePath(halfExtentX: halfExtentX, halfExtentY: halfExtentY)
            layer.isHidden = isHidden
        }
        if animationsChanged && self.areStarAnimationsActive {
            self.updateStarAnimations()
        }
    }

    private func updateEffects(tilt: WalletCardTilt) {
        let magnitude = tilt.x * tilt.x + tilt.y * tilt.y
        let magnitudeIndex = min(
            WalletCardEffectCache.stepCount,
            max(0, Int((magnitude * CGFloat(WalletCardEffectCache.stepCount) / 2.0).rounded()))
        )
        let colorIndex = min(
            WalletCardEffectCache.stepCount,
            max(0, Int(((tilt.y + 1.0) * CGFloat(WalletCardEffectCache.stepCount) / 2.0).rounded()))
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if self.currentColorEffectIndex != colorIndex {
            self.currentColorEffectIndex = colorIndex
            self.shineLayer.colors = WalletCardEffectCache.shineColors[colorIndex]
        }
        if self.currentMagnitudeEffectIndex != magnitudeIndex {
            self.currentMagnitudeEffectIndex = magnitudeIndex
            self.shineLayer.locations = WalletCardEffectCache.shineLocations[magnitudeIndex]
            self.starsMaskLayer.locations = WalletCardEffectCache.starLocations[magnitudeIndex]
        }
        self.shineLayer.endPoint = walletCardConicEndPoint(angle: (-58.0 + tilt.x * 60.0) * .pi / 180.0)

        self.starsMaskLayer.endPoint = walletCardConicEndPoint(angle: (-58.0 + tilt.x * 60.0) * .pi / 180.0)

        let shadowAngle = (212.0 + tilt.x * 60.0) * .pi / 180.0
        let shadowDistance = self.currentSize.width / walletCardBackgroundReferenceSize.width
        self.innerShadowLayer.shadowOffset = CGSize(
            width: -sin(shadowAngle) * shadowDistance,
            height: cos(shadowAngle) * shadowDistance
        )

        CATransaction.commit()
    }

    private func updateInnerShadowPath(bounds: CGRect, cornerRadius: CGFloat, scale: CGFloat) {
        let outerInset = 8.0 * scale
        let path = UIBezierPath(rect: bounds.insetBy(dx: -outerInset, dy: -outerInset))
        path.append(UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius))
        self.innerShadowLayer.path = path.cgPath
        self.innerShadowLayer.shadowRadius = 1.0 * scale
    }
}

private func walletCardConicLocations(spread: CGFloat) -> [NSNumber] {
    return [
        0.0,
        0.25 - spread,
        0.25,
        0.25 + spread,
        0.75 - spread,
        0.75,
        0.75 + spread,
        1.0
    ].map { NSNumber(value: Double($0)) }
}

private func walletCardConicEndPoint(angle: CGFloat) -> CGPoint {
    return CGPoint(
        x: 0.5 + cos(angle) * 0.5,
        y: 0.5 + sin(angle) * 0.5
    )
}

private func walletCardStarSize(x: CGFloat, y: CGFloat) -> CGFloat {
    let seed = (x * 7.31 + y * 13.17).truncatingRemainder(dividingBy: 100.0) / 100.0
    return 3.0 + abs(seed)
}

private func walletCardSparklePath(halfExtentX: CGFloat, halfExtentY: CGFloat) -> CGPath {
    let center = CGPoint(x: halfExtentX, y: halfExtentY)
    let thicknessX = halfExtentX * 0.18
    let thicknessY = halfExtentY * 0.18
    let path = UIBezierPath()
    path.move(to: CGPoint(x: center.x, y: center.y - halfExtentY))
    path.addLine(to: CGPoint(x: center.x + thicknessX, y: center.y - thicknessY))
    path.addLine(to: CGPoint(x: center.x + halfExtentX, y: center.y))
    path.addLine(to: CGPoint(x: center.x + thicknessX, y: center.y + thicknessY))
    path.addLine(to: CGPoint(x: center.x, y: center.y + halfExtentY))
    path.addLine(to: CGPoint(x: center.x - thicknessX, y: center.y + thicknessY))
    path.addLine(to: CGPoint(x: center.x - halfExtentX, y: center.y))
    path.addLine(to: CGPoint(x: center.x - thicknessX, y: center.y - thicknessY))
    path.close()
    return path.cgPath
}

private func walletCardShineColor(tiltY: CGFloat) -> UIColor {
    let baseLightness = 0.6320535731799914
    let baseChroma = 0.2017874155540712
    let hue = 254.08790274034567 * Double.pi / 180.0
    let lightness = baseLightness + 0.066 + Double(tiltY) * 0.1
    let chroma = baseChroma * 0.8
    let a = chroma * cos(hue)
    let b = chroma * sin(hue)

    let lComponent = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3.0)
    let mComponent = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3.0)
    let sComponent = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3.0)

    let linearRed = 4.0767416621 * lComponent - 3.3077115913 * mComponent + 0.2309699292 * sComponent
    let linearGreen = -1.2684380046 * lComponent + 2.6097574011 * mComponent - 0.3413193965 * sComponent
    let linearBlue = -0.0041960863 * lComponent - 0.7034186147 * mComponent + 1.7076147010 * sComponent

    return UIColor(
        red: CGFloat(walletCardLinearToSrgb(linearRed)),
        green: CGFloat(walletCardLinearToSrgb(linearGreen)),
        blue: CGFloat(walletCardLinearToSrgb(linearBlue)),
        alpha: 1.0
    )
}

private func walletCardLinearToSrgb(_ value: Double) -> Double {
    let clampedValue = max(0.0, min(1.0, value))
    if clampedValue <= 0.0031308 {
        return 12.92 * clampedValue
    } else {
        return 1.055 * pow(clampedValue, 1.0 / 2.4) - 0.055
    }
}

private func generateWalletCardTexture(width: Int, height: Int) -> CGImage? {
    let brushed = 0.35
    let amount = 1.0
    let aspectX = walletCardMix(150.0, 420.0, brushed)
    let aspectY = walletCardMix(150.0, 90.0, brushed)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let resolutionHeight = Double(height)

    for y in 0 ..< height {
        for x in 0 ..< width {
            let fragmentX = Double(x) + 0.5
            let fragmentY = Double(height - y) - 0.5
            let uvX = fragmentX / resolutionHeight
            let uvY = fragmentY / resolutionHeight
            let mottle = walletCardFbm(x: uvX * aspectX, y: uvY * aspectY) - 0.5
            let grain = walletCardValueNoise(x: fragmentX * 1.7, y: fragmentY * 1.7) - 0.5
            let modulation = (mottle * 0.06 + grain * 0.03) * amount
            let value = UInt8(max(0.0, min(255.0, (0.5 + modulation) * 255.0)).rounded())
            let offset = (y * width + x) * 4
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = 255
        }
    }

    let data = Data(pixels) as CFData
    guard let provider = CGDataProvider(data: data) else {
        return nil
    }
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}

private func walletCardHash(x: Double, y: Double) -> Double {
    var pointX = walletCardFract(x * 123.34)
    var pointY = walletCardFract(y * 456.21)
    let offset = pointX * (pointX + 45.32) + pointY * (pointY + 45.32)
    pointX += offset
    pointY += offset
    return walletCardFract(pointX * pointY)
}

private func walletCardValueNoise(x: Double, y: Double) -> Double {
    let integerX = floor(x)
    let integerY = floor(y)
    let fractionalX = walletCardFract(x)
    let fractionalY = walletCardFract(y)
    let a = walletCardHash(x: integerX, y: integerY)
    let b = walletCardHash(x: integerX + 1.0, y: integerY)
    let c = walletCardHash(x: integerX, y: integerY + 1.0)
    let d = walletCardHash(x: integerX + 1.0, y: integerY + 1.0)
    let smoothX = fractionalX * fractionalX * (3.0 - 2.0 * fractionalX)
    let smoothY = fractionalY * fractionalY * (3.0 - 2.0 * fractionalY)
    return walletCardMix(
        walletCardMix(a, b, smoothX),
        walletCardMix(c, d, smoothX),
        smoothY
    )
}

private func walletCardFbm(x: Double, y: Double) -> Double {
    var value = 0.0
    var amplitude = 0.5
    var pointX = x
    var pointY = y
    for _ in 0 ..< 4 {
        value += amplitude * walletCardValueNoise(x: pointX, y: pointY)
        pointX *= 2.0
        pointY *= 2.0
        amplitude *= 0.5
    }
    return value
}

private func walletCardMix(_ lhs: Double, _ rhs: Double, _ value: Double) -> Double {
    return lhs * (1.0 - value) + rhs * value
}

private func walletCardFract(_ value: Double) -> Double {
    return value - floor(value)
}
