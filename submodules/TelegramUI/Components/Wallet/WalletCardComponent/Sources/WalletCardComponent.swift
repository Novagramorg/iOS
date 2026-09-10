import Foundation
import UIKit
import CoreMotion
import QuartzCore
import simd
import Display
import ComponentFlow
import AnimatedTextComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent
import TelegramPresentationData
import TelegramStringFormatting
import WalletContext

public final class WalletCardComponent: Component {
    public let balance: Int64?
    public let fiatCurrency: WalletContext.FiatCurrency
    public let fiatRate: WalletContext.FiatRate?
    public let dateTimeFormat: PresentationDateTimeFormat
    public let name: String
    public let address: String
    public let isVisible: Bool
    public let qrPressed: () -> Void

    public init(
        balance: Int64?,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat,
        name: String,
        address: String,
        isVisible: Bool,
        qrPressed: @escaping () -> Void
    ) {
        self.balance = balance
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
        self.name = name
        self.address = address
        self.isVisible = isVisible
        self.qrPressed = qrPressed
    }

    public static func ==(lhs: WalletCardComponent, rhs: WalletCardComponent) -> Bool {
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.fiatCurrency != rhs.fiatCurrency || lhs.fiatRate != rhs.fiatRate {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        return true
    }

    public final class View: UIView {
        private static let maxPitch = 0.14
        private static let maxOverscrollPitch = 12.0 * Double.pi / 180.0
        private static let maxOverscrollScale = 1.05
        private static let maxYaw = 0.21
        private static let gyroGain = 0.9
        private static let highlightIdleGain = 1.75
        private static let foregroundZPosition: CGFloat = 128.0
        private static let maximumLiftShadowOpacity: Float = 0.16

        private let shadowView = UIView()
        private let backgroundView = WalletCardBackgroundView()
        private let foregroundView = UIControl()
        private let balanceTransitionView = UIView()
        private weak var balanceTransitionContainer: UIView?

        private let primaryBalanceCollapseContainerView = UIView()
        private let secondaryBalanceCollapseContainerView = UIView()
        private let primaryBalanceContainerView = UIView()
        private let secondaryBalanceContainerView = UIView()

        public private(set) var gramIconFrame: CGRect = .zero
        public private(set) var primaryBalanceSourceFrame: CGRect = .zero
        public private(set) var secondaryBalanceSourceFrame: CGRect = .zero
        public var balanceGeometryUpdated: (() -> Void)?

        private var gramIconContentFrame: CGRect = .zero
        private var primaryBalanceBaseFrame: CGRect = .zero
        private var secondaryBalanceBaseFrame: CGRect = .zero
        private var balanceTransitionFraction: CGFloat = 0.0
        private var balanceCollapseFraction: CGFloat = 0.0
        private var balanceScrollTransform = CATransform3DIdentity

        private let integralBalance = ComponentView<Empty>()
        private let fractionalBalance = ComponentView<Empty>()
        private let currency = ComponentView<Empty>()
        private let secondaryBalance = ComponentView<Empty>()
        private let name = ComponentView<Empty>()
        private let addressOutline = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let qrButton = ComponentView<Empty>()

        private let motionManager = CMMotionManager()
        private var displayLink: SharedDisplayLinkDriver.Link?

        private var gyroPitch = 0.0
        private var gyroRoll = 0.0
        private var panPitch = 0.0
        private var panRoll = 0.0
        private var overscrollPitch = 0.0
        private var isPanning = false
        private var baseAttitude: simd_quatd?

        private var currentCardX = 0.0
        private var currentCardY = 0.0
        private var currentDepthX = 0.0
        private var currentDepthY = 0.0
        private var currentHighlightX = 0.10
        private var currentHighlightY = -0.45
        private var currentScale = 1.0
        private var targetScale = 1.0
        private var idleTiltX = 0.0
        private var idleTiltY = 0.0
        private var elapsedTime = 0.0
        private var currentSize = CGSize.zero

        private var component: WalletCardComponent?

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.shadowView.isUserInteractionEnabled = false
            self.shadowView.backgroundColor = .clear
            self.shadowView.clipsToBounds = false
            self.shadowView.layer.masksToBounds = false
            self.shadowView.layer.shadowColor = UIColor.black.cgColor
            self.shadowView.layer.shadowOpacity = 0.0
            self.shadowView.layer.shadowRadius = 12.0
            self.shadowView.layer.shadowOffset = CGSize(width: 0.0, height: 7.0)
            self.addSubview(self.shadowView)

            self.addSubview(self.backgroundView)
            self.foregroundView.backgroundColor = .clear
            self.foregroundView.clipsToBounds = false
            self.foregroundView.layer.masksToBounds = false
            self.foregroundView.layer.allowsEdgeAntialiasing = true
            self.addSubview(self.foregroundView)

            self.balanceTransitionView.isUserInteractionEnabled = false
            self.balanceTransitionView.clipsToBounds = false
            self.balanceTransitionView.layer.allowsEdgeAntialiasing = true
            self.balanceTransitionView.layer.zPosition = Self.foregroundZPosition

            self.primaryBalanceCollapseContainerView.clipsToBounds = false
            self.secondaryBalanceCollapseContainerView.clipsToBounds = false
            self.primaryBalanceContainerView.clipsToBounds = false
            self.secondaryBalanceContainerView.clipsToBounds = false
            self.foregroundView.addSubview(self.primaryBalanceCollapseContainerView)
            self.foregroundView.addSubview(self.secondaryBalanceCollapseContainerView)
            self.primaryBalanceCollapseContainerView.addSubview(self.primaryBalanceContainerView)
            self.secondaryBalanceCollapseContainerView.addSubview(self.secondaryBalanceContainerView)

            self.shadowView.layer.zPosition = -Self.foregroundZPosition
            self.backgroundView.layer.zPosition = 0.0
            self.foregroundView.layer.zPosition = Self.foregroundZPosition

            self.backgroundColor = .clear
            self.clipsToBounds = false
            self.layer.masksToBounds = false
            self.layer.allowsEdgeAntialiasing = true
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true

            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(panGestureRecognizer)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.balanceTransitionView.removeFromSuperview()
            self.displayLink?.invalidate()
            self.motionManager.stopDeviceMotionUpdates()
            NotificationCenter.default.removeObserver(self)
        }

        override public func didMoveToWindow() {
            super.didMoveToWindow()

            self.updateAnimationState()
        }

        override public func willMove(toSuperview newSuperview: UIView?) {
            if newSuperview == nil {
                self.setBalanceTransitionContainer(nil)
            }
            super.willMove(toSuperview: newSuperview)
        }

        func update(
            component: WalletCardComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component

            let referenceSize = CGSize(width: 361.0, height: 220.0)
            let width = max(0.0, availableSize.width)
            let scale = width / referenceSize.width
            let size = CGSize(width: width, height: referenceSize.height * scale)
            let cornerRadius = 20.0 * scale

            self.backgroundColor = .clear
            self.clipsToBounds = false
            self.layer.masksToBounds = false
            self.currentSize = size

            self.shadowView.bounds = CGRect(origin: .zero, size: size)
            self.shadowView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.shadowView.layer.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            self.shadowView.layer.shadowRadius = 12.0 * scale
            self.shadowView.layer.shadowOffset = CGSize(width: 0.0, height: 7.0 * scale)
            self.shadowView.layer.shadowPath = UIBezierPath(
                roundedRect: self.shadowView.bounds,
                cornerRadius: cornerRadius
            ).cgPath

            self.foregroundView.bounds = CGRect(origin: .zero, size: size)
            self.foregroundView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.foregroundView.layer.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

            for collapseContainerView in [self.primaryBalanceCollapseContainerView, self.secondaryBalanceCollapseContainerView] {
                ComponentTransition.immediate.setBounds(
                    view: collapseContainerView,
                    bounds: CGRect(origin: CGPoint(), size: size)
                )
                ComponentTransition.immediate.setPosition(
                    view: collapseContainerView,
                    position: CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                )
            }

            let projectionPadding = WalletCardBackgroundView.projectionPadding
            transition.setFrame(
                view: self.backgroundView,
                frame: CGRect(
                    x: -projectionPadding,
                    y: -projectionPadding,
                    width: size.width + projectionPadding * 2.0,
                    height: size.height + projectionPadding * 2.0
                )
            )
            self.backgroundView.update(cardSize: size, cornerRadius: cornerRadius)

            let formattedBalance: String
            if let balance = component.balance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 2
                )
            } else {
                formattedBalance = "0"
            }

            let integralText: String
            let fractionalText: String
            if component.balance == nil || component.balance == 0 {
                integralText = formattedBalance
                fractionalText = ""
            } else if let decimalRange = formattedBalance.range(of: component.dateTimeFormat.decimalSeparator) {
                integralText = String(formattedBalance[..<decimalRange.lowerBound])
                var fractionalDigits = String(formattedBalance[decimalRange.upperBound...])
                while fractionalDigits.count < 2 {
                    fractionalDigits.append("0")
                }
                fractionalText = component.dateTimeFormat.decimalSeparator + fractionalDigits
            } else {
                integralText = formattedBalance
                fractionalText = component.dateTimeFormat.decimalSeparator + "00"
            }

            let secondaryText: String
            if let balance = component.balance, let fiatRate = component.fiatRate {
                secondaryText = formatTonFiatValue(
                    balance,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: balance == 0 ? 0 : 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                secondaryText = "—"
            }

            let mainColor = UIColor.white
            let secondaryColor = UIColor(rgb: 0x6ddcff)
            let integralSize = self.integralBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 22.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(
                            id: "gramIcon",
                            content: .icon("Wallet/CardGram", tint: false, offset: CGPoint(x: 0.0, y: -1.0))
                        ),
                        AnimatedTextComponent.Item(id: "gramIntegral", content: .text(integralText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let fractionalSize = self.fractionalBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 18.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: mainColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramFraction", content: .text(fractionalText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            let currencySize = self.currency.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 22.0,
                        design: .round,
                        weight: .semibold
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "gramCurrency", content: .text("GRAM"))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )

            let mainCenterY = 94.0
            let integralOriginY = floor(mainCenterY - integralSize.height * 0.5)
            let integralBottomY = integralOriginY + integralSize.height
            var mainOriginX = 20.0
            let integralFrame = CGRect(
                origin: CGPoint(x: mainOriginX, y: integralOriginY),
                size: integralSize
            )
            mainOriginX += integralSize.width
            if !fractionalText.isEmpty {
                mainOriginX += 1.0
            }
            let fractionalFrame = CGRect(
                origin: CGPoint(
                    x: mainOriginX,
                    y: floor(integralBottomY - fractionalSize.height - 2.0) - 1.0 - UIScreenPixel
                ),
                size: fractionalSize
            )
            mainOriginX += fractionalSize.width
            mainOriginX += 5.0
            let currencyFrame = CGRect(
                origin: CGPoint(x: mainOriginX, y: floor(integralBottomY - currencySize.height - 2.0)),
                size: currencySize
            )

            var primaryBalanceBaseFrame = integralFrame
            if !fractionalFrame.isEmpty {
                primaryBalanceBaseFrame = primaryBalanceBaseFrame.union(fractionalFrame)
            }
            self.primaryBalanceBaseFrame = primaryBalanceBaseFrame
            ComponentTransition.immediate.setBounds(
                view: self.primaryBalanceContainerView,
                bounds: CGRect(origin: CGPoint(), size: primaryBalanceBaseFrame.size)
            )
            ComponentTransition.immediate.setPosition(
                view: self.primaryBalanceContainerView,
                position: primaryBalanceBaseFrame.center
            )

            if let gramIconSize = UIImage(bundleImageName: "Wallet/CardGram")?.size {
                self.gramIconContentFrame = CGRect(
                    origin: CGPoint(
                        x: integralFrame.minX - primaryBalanceBaseFrame.minX,
                        y: integralFrame.minY - primaryBalanceBaseFrame.minY - 1.0
                    ),
                    size: gramIconSize
                )
            } else {
                self.gramIconContentFrame = .zero
                self.gramIconFrame = .zero
            }
            if let integralView = self.integralBalance.view {
                if integralView.superview !== self.primaryBalanceContainerView {
                    self.primaryBalanceContainerView.addSubview(integralView)
                }
                transition.setFrame(
                    view: integralView,
                    frame: integralFrame.offsetBy(
                        dx: -primaryBalanceBaseFrame.minX,
                        dy: -primaryBalanceBaseFrame.minY
                    )
                )
            }
            if let fractionalView = self.fractionalBalance.view {
                if fractionalView.superview !== self.primaryBalanceContainerView {
                    self.primaryBalanceContainerView.addSubview(fractionalView)
                }
                transition.setFrame(
                    view: fractionalView,
                    frame: fractionalFrame.offsetBy(
                        dx: -primaryBalanceBaseFrame.minX,
                        dy: -primaryBalanceBaseFrame.minY
                    )
                )
            }
            if let currencyView = self.currency.view {
                if currencyView.superview !== self.primaryBalanceContainerView {
                    self.primaryBalanceContainerView.addSubview(currencyView)
                }
                transition.setFrame(
                    view: currencyView,
                    frame: currencyFrame.offsetBy(
                        dx: -primaryBalanceBaseFrame.minX,
                        dy: -primaryBalanceBaseFrame.minY
                    )
                )
            }

            let secondarySize = self.secondaryBalance.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(
                        size: 14.0,
                        design: .round,
                        weight: .semibold,
                        traits: .monospacedNumbers
                    ),
                    color: secondaryColor,
                    items: [
                        AnimatedTextComponent.Item(id: "secondaryBalance", content: .text(secondaryText))
                    ],
                    noDelay: true
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 100.0)
            )
            self.secondaryBalanceBaseFrame = CGRect(
                origin: CGPoint(x: 24.0, y: 114.0),
                size: secondarySize
            )
            ComponentTransition.immediate.setBounds(
                view: self.secondaryBalanceContainerView,
                bounds: CGRect(origin: CGPoint(), size: secondarySize)
            )
            ComponentTransition.immediate.setPosition(
                view: self.secondaryBalanceContainerView,
                position: self.secondaryBalanceBaseFrame.center
            )
            if let secondaryView = self.secondaryBalance.view {
                if secondaryView.superview !== self.secondaryBalanceContainerView {
                    self.secondaryBalanceContainerView.addSubview(secondaryView)
                }
                transition.setFrame(
                    view: secondaryView,
                    frame: CGRect(origin: CGPoint(), size: secondarySize)
                )
            }

            let nameSize = self.name.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.name,
                        font: Font.with(size: 14.0, design: .monospace, weight: .semibold),
                        textColor: mainColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: width - 96.0 * scale, height: 50.0)
            )
            if let nameView = self.name.view {
                if nameView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(nameView)
                }
                transition.setFrame(
                    view: nameView,
                    frame: CGRect(
                        origin: CGPoint(x: 24.0, y: size.height - 35.0),
                        size: nameSize
                    )
                )
            }

            let qrSize = self.qrButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Wallet/CardQr",
                        tintColor: nil,
                        scaleFactor: scale
                    )),
                    minSize: CGSize(width: 50.0, height: 38.0),
                    action: { [weak self] in
                        self?.component?.qrPressed()
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: 80.0 * scale, height: 80.0)
            )
            if let qrView = self.qrButton.view {
                if qrView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(qrView)
                }
                transition.setFrame(
                    view: qrView,
                    frame: CGRect(
                        origin: CGPoint(x: width - 97.0 * scale, y: 82.0 * scale),
                        size: qrSize
                    )
                )
            }

            let addressText = formattedWalletAddress(component.address)

            let _ = self.addressOutline.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: addressText.uppercased(),
                        font: Font.monospace(11.0),
                        textColor: UIColor(rgb: 0xffffff, alpha: 0.1)
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: -0.05
                )),
                environment: {},
                containerSize: CGSize(width: size.height, height: 50.0)
            )
            let addressSize = self.address.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: addressText.uppercased(),
                        font: Font.monospace(11.0),
                        textColor: UIColor(rgb: 0x055ac4, alpha: 0.8)
                    )),
                    maximumNumberOfLines: 2,
                    lineSpacing: -0.05
                )),
                environment: {},
                containerSize: CGSize(width: size.height, height: 50.0)
            )
            if let addressView = self.addressOutline.view {
                if addressView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(addressView)
                }
                addressView.transform = .identity
                addressView.bounds = CGRect(origin: CGPoint(), size: addressSize)
                addressView.center = CGPoint(x: width - 27.0, y: size.height * 0.5 + 1.0)
                addressView.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
            }
            if let addressView = self.address.view {
                if addressView.superview !== self.foregroundView {
                    self.foregroundView.addSubview(addressView)
                }
                addressView.transform = .identity
                addressView.bounds = CGRect(origin: CGPoint(), size: addressSize)
                addressView.center = CGPoint(x: width - 27.0, y: size.height * 0.5)
                addressView.transform = CGAffineTransform(rotationAngle: .pi / 2.0)
            }

            self.updateAnimationState()
            self.renderCurrentFrame()

            return size
        }

        private func displayLinkDidFire(_ frameDuration: CGFloat) {
            let deltaTime = min(max(Double(frameDuration), 0.0), 1.0 / 30.0)
            guard deltaTime > 0.0 else {
                return
            }
            self.elapsedTime += deltaTime

            if !self.isPanning {
                let decay = exp(-deltaTime * 4.0)
                self.panPitch *= decay
                self.panRoll *= decay
            }

            let idleX = 0.013 * sin(self.elapsedTime * 0.50)
            let idleY = 0.022 * sin(self.elapsedTime * 0.37 + 1.6)
            self.idleTiltX = idleX
            self.idleTiltY = idleY

            let cardTargetX = Self.clamp(self.panPitch, Self.maxPitch)
            let cardTargetY = Self.clamp(self.panRoll, Self.maxYaw)
            let depthTargetX = Self.clamp(
                self.gyroPitch + self.panPitch,
                Self.maxPitch + 0.03
            )
            let depthTargetY = Self.clamp(
                self.gyroRoll + self.panRoll,
                Self.maxYaw + 0.03
            )
            let highlightTargetX = Self.clamp(
                self.gyroPitch + self.panPitch + idleX,
                Self.maxPitch + 0.03
            )
            let highlightTargetY = Self.clamp(
                self.gyroRoll + self.panRoll + idleY,
                Self.maxYaw + 0.03
            )
            let smoothing = 1.0 - exp(-deltaTime * 8.0)
            self.currentCardX += (cardTargetX - self.currentCardX) * smoothing
            self.currentCardY += (cardTargetY - self.currentCardY) * smoothing
            self.currentDepthX += (depthTargetX - self.currentDepthX) * smoothing
            self.currentDepthY += (depthTargetY - self.currentDepthY) * smoothing
            self.currentHighlightX += (highlightTargetX - self.currentHighlightX) * smoothing
            self.currentHighlightY += (highlightTargetY - self.currentHighlightY) * smoothing
            self.currentScale += (self.targetScale - self.currentScale) * (1.0 - exp(-deltaTime * 12.0))

            self.renderCurrentFrame()
        }

        private func updateAnimationState() {
            guard self.component?.isVisible == true,
                  self.window != nil,
                  UIApplication.shared.applicationState == .active else {
                self.stopAnimation()
                return
            }

            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] frameDuration in
                    self?.displayLinkDidFire(frameDuration)
                }
            }
            self.startMotionIfPossible()
        }

        private func stopAnimation() {
            self.displayLink?.invalidate()
            self.displayLink = nil
            self.motionManager.stopDeviceMotionUpdates()
            self.baseAttitude = nil
            self.gyroPitch = 0.0
            self.gyroRoll = 0.0
        }

        private func startMotionIfPossible() {
            guard
                self.displayLink != nil,
                self.motionManager.isDeviceMotionAvailable,
                !self.motionManager.isDeviceMotionActive
            else {
                return
            }

            self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            self.motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
                guard let self, self.displayLink != nil, let data else {
                    return
                }

                let quaternion = data.attitude.quaternion
                let current = simd_normalize(simd_quatd(
                    ix: quaternion.x,
                    iy: quaternion.y,
                    iz: quaternion.z,
                    r: quaternion.w
                ))

                guard let baseAttitude = self.baseAttitude else {
                    self.baseAttitude = current
                    return
                }

                var relative = baseAttitude.conjugate * current
                if relative.real < 0.0 {
                    relative = simd_quatd(vector: -relative.vector)
                }

                let deviceNormal = simd_act(relative, SIMD3<Double>(0.0, 0.0, 1.0))
                let screenNormal = self.screenOrientedNormal(deviceNormal)
                let forward = max(screenNormal.z, 0.15)
                let pitch = atan2(screenNormal.y, forward) * Self.gyroGain
                let roll = atan2(screenNormal.x, forward) * Self.gyroGain
                self.gyroPitch = Self.clamp(pitch, Self.maxPitch * 0.85)
                self.gyroRoll = Self.clamp(roll, Self.maxYaw * 0.8)
            }
        }

        private func screenOrientedNormal(_ normal: SIMD3<Double>) -> SIMD3<Double> {
            switch self.window?.windowScene?.interfaceOrientation ?? .portrait {
            case .portrait:
                return normal
            case .portraitUpsideDown:
                return SIMD3<Double>(-normal.x, -normal.y, normal.z)
            case .landscapeLeft:
                return SIMD3<Double>(normal.y, -normal.x, normal.z)
            case .landscapeRight:
                return SIMD3<Double>(-normal.y, normal.x, normal.z)
            default:
                return normal
            }
        }

        public func updateOverscroll(distance: CGFloat) {
            let pitch = -Self.maxOverscrollPitch * Double(min(1.0, max(0.0, distance) / 120.0))
            guard self.overscrollPitch != pitch else {
                return
            }
            self.overscrollPitch = pitch
            self.renderCurrentFrame()
        }

        public func setBalanceTransitionContainer(_ container: UIView?) {
            let foregroundView: UIView = container == nil ? self.foregroundView : self.balanceTransitionView
            guard self.balanceTransitionContainer !== container || self.primaryBalanceCollapseContainerView.superview !== foregroundView else {
                return
            }
            self.balanceTransitionContainer = container
            if let container {
                container.addSubview(self.balanceTransitionView)
            }
            foregroundView.addSubview(self.primaryBalanceCollapseContainerView)
            foregroundView.addSubview(self.secondaryBalanceCollapseContainerView)
            if container == nil {
                self.balanceTransitionView.removeFromSuperview()
                self.updateBalanceTransition(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    primaryCollapsedFrame: nil,
                    secondaryCollapsedFrame: nil,
                    fraction: 0.0,
                    collapseFraction: 0.0,
                    transition: .immediate
                )
            } else {
                self.updateBalanceTransitionGeometry()
                self.updateProjectedBalanceFrames()
            }
        }

        private func updateBalanceTransitionGeometry() {
            guard self.balanceTransitionContainer != nil else {
                return
            }

            ComponentTransition.immediate.setBounds(view: self.balanceTransitionView, bounds: self.foregroundView.bounds)
            ComponentTransition.immediate.setPosition(view: self.balanceTransitionView, position: self.foregroundView.layer.position)

            let fraction = 1.0 - max(0.0, min(1.0, self.balanceCollapseFraction))
            var transform = CATransform3DConcat(self.foregroundView.layer.transform, self.balanceScrollTransform)
            transform.m11 = 1.0 + (transform.m11 - 1.0) * fraction
            transform.m12 *= fraction
            transform.m13 *= fraction
            transform.m14 *= fraction
            transform.m21 *= fraction
            transform.m22 = 1.0 + (transform.m22 - 1.0) * fraction
            transform.m23 *= fraction
            transform.m24 *= fraction
            transform.m31 *= fraction
            transform.m32 *= fraction
            transform.m33 = 1.0 + (transform.m33 - 1.0) * fraction
            transform.m34 *= fraction
            transform.m41 *= fraction
            transform.m42 *= fraction
            transform.m43 *= fraction
            transform.m44 = 1.0 + (transform.m44 - 1.0) * fraction
            ComponentTransition.immediate.setTransform(view: self.balanceTransitionView, transform: transform)
        }

        public func updateBalanceTransition(
            primaryFrame: CGRect?,
            secondaryFrame: CGRect?,
            primaryCollapsedFrame: CGRect?,
            secondaryCollapsedFrame: CGRect?,
            fraction: CGFloat,
            collapseFraction: CGFloat,
            scrollTransform: CATransform3D = CATransform3DIdentity,
            transition: ComponentTransition
        ) {
            let fraction = max(0.0, min(1.0, fraction))
            self.balanceTransitionFraction = fraction
            self.balanceCollapseFraction = collapseFraction
            self.balanceScrollTransform = scrollTransform
            self.updateBalanceTransitionGeometry()

            self.updateBalanceContainer(
                self.primaryBalanceCollapseContainerView,
                self.primaryBalanceContainerView,
                baseFrame: self.primaryBalanceBaseFrame,
                targetFrame: primaryFrame,
                collapsedFrame: primaryCollapsedFrame,
                collapseFraction: collapseFraction
            )
            self.updateBalanceContainer(
                self.secondaryBalanceCollapseContainerView,
                self.secondaryBalanceContainerView,
                baseFrame: self.secondaryBalanceBaseFrame,
                targetFrame: secondaryFrame,
                collapsedFrame: secondaryCollapsedFrame,
                collapseFraction: collapseFraction
            )
            if let currencyView = self.currency.view {
                transition.setAlpha(view: currencyView, alpha: 1.0 - fraction)
            }
            self.updateProjectedBalanceFrames()
        }

        private func updateBalanceContainer(
            _ collapseContainerView: UIView,
            _ containerView: UIView,
            baseFrame: CGRect,
            targetFrame: CGRect?,
            collapsedFrame: CGRect?,
            collapseFraction: CGFloat
        ) {
            guard !baseFrame.isEmpty,
                  let targetFrame,
                  !targetFrame.isEmpty,
                  targetFrame.width.isFinite,
                  targetFrame.height.isFinite else {
                ComponentTransition.immediate.setPosition(view: containerView, position: baseFrame.center)
                ComponentTransition.immediate.setTransform(view: containerView, transform: CATransform3DIdentity)
                ComponentTransition.immediate.setTransform(view: collapseContainerView, transform: CATransform3DIdentity)
                return
            }

            let foregroundView: UIView
            let coordinateView: UIView
            if let balanceTransitionContainer = self.balanceTransitionContainer {
                foregroundView = self.balanceTransitionView
                coordinateView = balanceTransitionContainer
            } else {
                foregroundView = self.foregroundView
                coordinateView = self
            }
            let targetFrameInForeground = foregroundView.convert(targetFrame, from: coordinateView)
            let scaleX = targetFrameInForeground.width / baseFrame.width
            let scaleY = targetFrameInForeground.height / baseFrame.height
            ComponentTransition.immediate.setPosition(
                view: containerView,
                position: targetFrameInForeground.center
            )
            ComponentTransition.immediate.setTransform(
                view: containerView,
                transform: CATransform3DMakeScale(scaleX, scaleY, 1.0)
            )

            let collapseTransform: CATransform3D
            if let collapsedFrame,
               !collapsedFrame.isEmpty,
               collapsedFrame.width.isFinite,
               collapsedFrame.height.isFinite {
                collapseTransform = self.collapseTransform(
                    in: collapseContainerView,
                    from: targetFrameInForeground,
                    to: foregroundView.convert(collapsedFrame, from: coordinateView),
                    fraction: collapseFraction
                )
            } else {
                collapseTransform = CATransform3DIdentity
            }
            ComponentTransition.immediate.setTransform(view: collapseContainerView, transform: collapseTransform)
        }

        private func collapseTransform(in containerView: UIView, from sourceFrame: CGRect, to targetFrame: CGRect, fraction: CGFloat) -> CATransform3D {
            let scaleX = targetFrame.width / sourceFrame.width
            let scaleY = targetFrame.height / sourceFrame.height
            let anchor = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
            var transform = CATransform3DMakeScale(1.0 + (scaleX - 1.0) * fraction, 1.0 + (scaleY - 1.0) * fraction, 1.0)
            transform.m41 = (targetFrame.midX - anchor.x - (sourceFrame.midX - anchor.x) * scaleX) * fraction
            transform.m42 = (targetFrame.midY - anchor.y - (sourceFrame.midY - anchor.y) * scaleY) * fraction
            return transform
        }

        private func updateProjectedBalanceFrames() {
            if self.primaryBalanceBaseFrame.isEmpty {
                self.primaryBalanceSourceFrame = .zero
            } else {
                self.primaryBalanceSourceFrame = self.foregroundView.convert(
                    self.primaryBalanceBaseFrame,
                    to: self
                )
            }
            if self.secondaryBalanceBaseFrame.isEmpty {
                self.secondaryBalanceSourceFrame = .zero
            } else {
                self.secondaryBalanceSourceFrame = self.foregroundView.convert(
                    self.secondaryBalanceBaseFrame,
                    to: self
                )
            }
            if self.gramIconContentFrame.isEmpty {
                self.gramIconFrame = .zero
            } else {
                self.gramIconFrame = self.primaryBalanceContainerView.convert(
                    self.gramIconContentFrame,
                    to: self
                )
            }
        }

        private func makePerspectiveTransform(pitch: Double, scale: Double) -> CATransform3D {
            var perspectiveTransform = CATransform3DIdentity
            perspectiveTransform.m34 = -1.0 / 650.0
            perspectiveTransform = CATransform3DTranslate(
                perspectiveTransform,
                CGFloat(-self.currentCardY * 10.0),
                CGFloat(self.currentCardX * 8.0),
                0.0
            )
            perspectiveTransform = CATransform3DScale(
                perspectiveTransform,
                CGFloat(scale),
                CGFloat(scale),
                1.0
            )
            perspectiveTransform = CATransform3DRotate(
                perspectiveTransform,
                CGFloat(pitch),
                1.0,
                0.0,
                0.0
            )
            perspectiveTransform = CATransform3DRotate(
                perspectiveTransform,
                CGFloat(self.currentCardY),
                0.0,
                1.0,
                0.0
            )
            perspectiveTransform = CATransform3DRotate(
                perspectiveTransform,
                CGFloat(self.currentCardY * 0.05),
                0.0,
                0.0,
                1.0
            )

            return perspectiveTransform
        }

        private func renderCurrentFrame() {
            guard self.currentSize.width > 0.0, self.currentSize.height > 0.0 else {
                return
            }

            let maxPitch = max(Self.maxPitch, Self.maxOverscrollPitch)
            let cardPitch = Self.clamp(self.currentCardX + self.overscrollPitch, maxPitch)
            let overscrollFraction = -self.overscrollPitch / Self.maxOverscrollPitch
            let overscrollScale = 1.0 + (Self.maxOverscrollScale - 1.0) * overscrollFraction
            var perspectiveTransform = self.makePerspectiveTransform(pitch: cardPitch, scale: self.currentScale * overscrollScale)
            if self.overscrollPitch != 0.0 {
                func projectedBottomY(_ transform: CATransform3D) -> CGFloat {
                    let y = self.currentSize.height * 0.5
                    let w = y * transform.m24 + transform.m44
                    let safeW = abs(w) < 0.0001 ? 0.0001 : w
                    return (y * transform.m22 + transform.m42) / safeW
                }

                let baseTransform = self.makePerspectiveTransform(pitch: self.currentCardX, scale: self.currentScale)
                let bottomOffset = projectedBottomY(baseTransform) - projectedBottomY(perspectiveTransform)
                perspectiveTransform = CATransform3DConcat(
                    perspectiveTransform,
                    CATransform3DMakeTranslation(0.0, bottomOffset, 0.0)
                )
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.shadowView.layer.transform = perspectiveTransform
            self.foregroundView.layer.transform = perspectiveTransform
            let liftProgress = max(0.0, min(1.0, (self.currentScale - 1.0) / 0.02))
            let easedLiftProgress = liftProgress * liftProgress * (3.0 - 2.0 * liftProgress)
            self.shadowView.layer.shadowOpacity = Self.maximumLiftShadowOpacity * Float(easedLiftProgress)
            CATransaction.commit()
            self.updateBalanceTransitionGeometry()
            self.backgroundView.updateFallbackTransform(perspectiveTransform)

            let projectedQuad = self.projectedQuad(for: perspectiveTransform)

            self.updateProjectedBalanceFrames()

            let additionalIdleGain = Self.highlightIdleGain - 1.0
            self.backgroundView.render(
                time: self.elapsedTime,
                highlightTiltX: Self.clamp(self.currentHighlightX + self.overscrollPitch, maxPitch + 0.03) + self.idleTiltX * additionalIdleGain,
                highlightTiltY: self.currentHighlightY + self.idleTiltY * additionalIdleGain,
                surfaceTiltX: Self.clamp(self.currentDepthX + self.overscrollPitch, maxPitch + 0.03),
                surfaceTiltY: self.currentDepthY,
                quad: projectedQuad
            )

            if self.balanceTransitionFraction > 0.0 && self.balanceTransitionFraction < 1.0 {
                self.balanceGeometryUpdated?()
            }
        }

        private func projectedQuad(for transform: CATransform3D) -> WalletCardProjectedQuad {
            let sourceBounds = CGRect(origin: .zero, size: self.currentSize)
            let anchor = CGPoint(x: sourceBounds.midX, y: sourceBounds.midY)
            let position = anchor

            func project(_ point: CGPoint) -> (point: CGPoint, w: CGFloat) {
                let x = point.x - anchor.x
                let y = point.y - anchor.y
                let transformedX = x * transform.m11 + y * transform.m21 + transform.m41
                let transformedY = x * transform.m12 + y * transform.m22 + transform.m42
                let transformedW = x * transform.m14 + y * transform.m24 + transform.m44
                let safeW = abs(transformedW) < 0.0001 ? 0.0001 : transformedW
                return (
                    CGPoint(
                        x: position.x + transformedX / safeW,
                        y: position.y + transformedY / safeW
                    ),
                    safeW
                )
            }

            let topLeft = project(CGPoint(x: sourceBounds.minX, y: sourceBounds.minY))
            let topRight = project(CGPoint(x: sourceBounds.maxX, y: sourceBounds.minY))
            let bottomLeft = project(CGPoint(x: sourceBounds.minX, y: sourceBounds.maxY))
            let bottomRight = project(CGPoint(x: sourceBounds.maxX, y: sourceBounds.maxY))

            func clipPosition(_ projected: (point: CGPoint, w: CGFloat)) -> SIMD4<Float> {
                let padding = WalletCardBackgroundView.projectionPadding
                let width = max(self.currentSize.width + padding * 2.0, 1.0)
                let height = max(self.currentSize.height + padding * 2.0, 1.0)
                let normalizedX = Float(((projected.point.x + padding) / width) * 2.0 - 1.0)
                let normalizedY = Float(1.0 - ((projected.point.y + padding) / height) * 2.0)
                let w = Float(projected.w)
                return SIMD4<Float>(normalizedX * w, normalizedY * w, 0.0, w)
            }

            return WalletCardProjectedQuad(
                bottomLeft: clipPosition(bottomLeft),
                bottomRight: clipPosition(bottomRight),
                topLeft: clipPosition(topLeft),
                topRight: clipPosition(topRight)
            )
        }

        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            switch gestureRecognizer.state {
            case .began:
                self.isPanning = true
                self.targetScale = 1.02
            case .changed:
                let translation = gestureRecognizer.translation(in: self)
                let designScale = max(self.currentSize.width / 361.0, 0.01)
                let travel = 240.0 * designScale
                self.panRoll = Self.clamp(Double(translation.x / travel) * Self.maxYaw, Self.maxYaw)
                self.panPitch = Self.clamp(-Double(translation.y / travel) * Self.maxPitch, Self.maxPitch)
            case .ended, .cancelled, .failed:
                self.isPanning = false
                self.targetScale = 1.0
            default:
                break
            }
        }

        @objc private func applicationDidBecomeActive() {
            self.baseAttitude = nil
            self.gyroPitch = 0.0
            self.gyroRoll = 0.0
            self.currentDepthX = self.currentCardX
            self.currentDepthY = self.currentCardY
            self.idleTiltX = 0.0
            self.idleTiltY = 0.0
            self.updateAnimationState()
        }

        @objc private func applicationWillResignActive() {
            self.stopAnimation()
        }

        private static func clamp(_ value: Double, _ limit: Double) -> Double {
            return max(-limit, min(limit, value))
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

private func formattedWalletAddress(_ address: String) -> String {
    var groups: [String] = []
    var currentIndex = address.startIndex
    while currentIndex < address.endIndex {
        let endIndex = address.index(currentIndex, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
        groups.append(String(address[currentIndex ..< endIndex]))
        currentIndex = endIndex
    }

    let splitIndex = min(6, groups.count)
    let firstLine = groups[..<splitIndex].joined(separator: " ")
    let secondLine = groups.dropFirst(splitIndex).joined(separator: " ")
    if secondLine.isEmpty {
        return firstLine
    } else {
        return firstLine + "\n" + secondLine
    }
}
