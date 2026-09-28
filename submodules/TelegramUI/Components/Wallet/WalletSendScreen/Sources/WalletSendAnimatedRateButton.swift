import Foundation
import UIKit
import AppBundle
import Display
import ComponentFlow
import AnimatedTextComponent
import GlassBackgroundComponent
import TelegramPresentationData

final class WalletSendAnimatedRateButton: UIControl {
    private let contentView = UIView()
    private let glassBackgroundView: GlassBackgroundView?
    private let glassButton: UIButton?
    private let canvas = WalletSendAmountCanvas(frame: .zero)
    private let title = ComponentView<Empty>()
    private let gramIcon = UIImageView()
    private var arrows: [UIImageView] = []
    private let motion = WalletSendAmountMotion()
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var arrowTiming: WalletSendAmountMotionTiming?
    private var arrowFrom: CGFloat = 0.0
    private var arrowTo: CGFloat = 0.0
    private var arrowPhase: CGFloat = 0.0
    private var arrowPaceFrom: CGFloat = 0.0
    private var arrowPace: CGFloat = 0.0
    private var geometryTiming: WalletSendAmountMotionTiming?
    private var previousMode: WalletSendInputMode?
    private var widthFrom: CGFloat = 22.0
    private var widthTo: CGFloat = 22.0
    private var currentWidth: CGFloat = 22.0
    private var gramFrom: CGFloat = 0.0
    private var gramTo: CGFloat = 0.0
    private var currentGram: CGFloat = 0.0
    private var visible = false
    private var isDark = false
    private var frameDuration = 1.0 / 120.0
    var action: (() -> Void)?

    override init(frame: CGRect) {
        if #available(iOS 27.0, *) {
            self.glassBackgroundView = GlassBackgroundView()
            self.glassButton = UIButton(type: .custom)
        } else {
            self.glassBackgroundView = nil
            self.glassButton = nil
        }
        super.init(frame: frame)
        self.isExclusiveTouch = true
        self.isAccessibilityElement = true
        self.accessibilityTraits = .button
        self.contentView.isUserInteractionEnabled = false
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = 13.0
        if let glassBackgroundView = self.glassBackgroundView, let glassButton = self.glassButton {
            self.addSubview(glassBackgroundView)
            glassBackgroundView.contentView.addSubview(self.contentView)
            glassBackgroundView.contentView.addSubview(glassButton)
            glassButton.isExclusiveTouch = true
            glassButton.isAccessibilityElement = false
            glassButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        } else {
            self.addSubview(self.contentView)
        }
        self.contentView.addSubview(self.canvas)
        self.canvas.onFrameReady = { [weak self] in
            guard let self, self.visible, self.window != nil else { return }
            self.canvas.isHidden = false
            self.title.view?.isHidden = true
        }
        self.gramIcon.image = UIImage(bundleImageName: "Wallet/TopGram")
        self.gramIcon.contentMode = .scaleAspectFit
        self.contentView.addSubview(self.gramIcon)
        for side in 0 ..< 2 {
            for _ in 0 ..< 5 {
                let view = UIImageView(image: UIImage(bundleImageName: "Wallet/Swap")?.withRenderingMode(.alwaysTemplate))
                view.contentMode = .scaleAspectFit
                let mask = CAShapeLayer()
                mask.path = CGPath(rect: CGRect(x: CGFloat(side) * 9.0, y: 0.0, width: 9.0, height: 18.0), transform: nil)
                view.layer.mask = mask
                self.contentView.addSubview(view)
                self.arrows.append(view)
            }
        }
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopAnimations), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopAnimations), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.resumePresentation), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        self.displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func stopAnimations() { self.finishMotion() }
    @objc private func resumePresentation() { self.setNeedsLayout() }

    @objc private func pressed() { self.action?() }

    override var isHighlighted: Bool {
        didSet {
            guard self.glassBackgroundView == nil else { return }
            let scale: CGFloat = self.isHighlighted && !UIAccessibility.isReduceMotionEnabled ? 0.94 : 1.0
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.15 : 0.28, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
            })
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil { self.finishMotion() }
    }

    func update(
        text: String, displaysGramIcon: Bool, mode: WalletSendInputMode, currencyCode: String,
        dateTimeFormat: PresentationDateTimeFormat, theme: PresentationTheme,
        isVisible: Bool, isEnabled: Bool, timing sharedTiming: WalletSendAmountMotionTiming?,
        maxWidth: CGFloat
    ) -> CGSize {
        let wasVisible = self.visible
        self.visible = isVisible
        self.isEnabled = isEnabled
        self.glassButton?.isEnabled = isEnabled
        self.isDark = theme.overallDarkAppearance
        self.accessibilityLabel = displaysGramIcon ? "GRAM " + text : text
        self.contentView.backgroundColor = self.glassBackgroundView == nil ? theme.list.itemInputField.backgroundColor : .clear
        for arrow in self.arrows { arrow.tintColor = theme.list.itemSecondaryTextColor }
        self.canvas.prepareGlyphs(separators: dateTimeFormat.decimalSeparator + dateTimeFormat.groupingSeparator, currencyCode: currencyCode)
        let font = WalletSendAmountFonts.rate
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(AnimatedTextComponent(font: font, color: theme.list.itemSecondaryTextColor, items: [.init(id: "rate", content: .text(text))], noDelay: true, blur: true)),
            environment: {}, containerSize: CGSize(width: max(1.0, maxWidth - 56.0), height: 26.0)
        )
        let textWidth = titleSize.width
        let gramWidth: CGFloat = displaysGramIcon ? 19.0 : 0.0
        let width = min(maxWidth, max(22.0, 16.0 + gramWidth + textWidth + 3.0 + 18.0))
        let titleOrigin = CGPoint(x: 8.0 + gramWidth, y: floorToScreenPixels((26.0 - titleSize.height) / 2.0))
        var glyphs: [WalletSendAmountGlyph] = []
        if let titleView = self.title.view {
            if titleView.superview == nil {
                titleView.isUserInteractionEnabled = false
                titleView.accessibilityElementsHidden = true
                self.contentView.addSubview(titleView)
            }
            titleView.frame = CGRect(origin: titleOrigin, size: titleSize)
            glyphs = walletSendAmountComponentGlyphs(titleView, origin: titleOrigin)
        }
        var inFraction = false
        var passedNumber = false
        for i in glyphs.indices {
            let value = glyphs[i].text
            if value == dateTimeFormat.decimalSeparator {
                inFraction = true
                glyphs[i].group = .fraction
            } else if value == dateTimeFormat.groupingSeparator && !value.isEmpty && !passedNumber {
                glyphs[i].group = .grouping
            } else if value.first?.wholeNumberValue != nil {
                glyphs[i].group = inFraction ? .fraction : .integer
            } else if value == "~" {
                glyphs[i].group = .prefix
            } else {
                passedNumber = true
                glyphs[i].group = .suffix
            }
        }
        let switched = self.previousMode != nil && self.previousMode != mode
        if glyphs != self.motion.target || self.widthTo != width || self.gramTo != (displaysGramIcon ? 1.0 : 0.0) {
            let now = CACurrentMediaTime()
            let sharedStart = sharedTiming.flatMap { now - $0.start < $0.duration ? $0.start : nil }
            let timing: WalletSendAmountMotionTiming?
            if self.previousMode != nil && wasVisible && isVisible && self.window != nil && self.canvas.isAvailable {
                timing = WalletSendAmountMotionTiming(spin: switched, up: !(sharedTiming?.up ?? true), start: sharedStart ?? now)
            } else {
                timing = nil
            }
            let previousProgress = self.geometryTiming?.layoutProgress(at: now) ?? 1.0
            self.widthFrom = self.widthFrom + (self.widthTo - self.widthFrom) * previousProgress + self.motion.widthAdjustment(at: now)
            self.widthTo = width
            self.gramFrom = self.gramFrom + (self.gramTo - self.gramFrom) * previousProgress
            self.gramTo = displaysGramIcon ? 1.0 : 0.0
            self.geometryTiming = timing
            self.motion.update(glyphs, width: width, timing: timing, at: now, frameDuration: self.frameDuration)
            if switched {
                self.arrowTiming = timing
                self.arrowFrom = self.arrowPhase
                self.arrowTo = floor(self.arrowPhase) + 1.0
                self.arrowPaceFrom = self.arrowPace
            }
        }
        self.previousMode = mode
        if !isVisible { self.finishMotion() }
        self.renderFrame()
        if self.isAnimating && self.displayLink == nil {
            self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] duration in
                guard let self else { return }
                self.frameDuration += (Double(duration) - self.frameDuration) * 0.3
                self.renderFrame()
            })
        }
        return CGSize(width: width, height: 26.0)
    }

    private var isAnimating: Bool {
        let now = CACurrentMediaTime()
        return self.visible && (self.motion.isAnimating(at: now) || (self.geometryTiming?.progress(at: now) ?? 1.0) < 1.0 || (self.arrowTiming?.progress(at: now) ?? 1.0) < 1.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.renderFrame()
    }

    private func renderFrame() {
        let now = CACurrentMediaTime()
        if !self.isAnimating {
            self.motion.finish()
            self.geometryTiming = nil
            self.arrowTiming = nil
        }
        let p = self.geometryTiming?.layoutProgress(at: now) ?? 1.0
        self.currentWidth = self.widthFrom + (self.widthTo - self.widthFrom) * p + self.motion.widthAdjustment(at: now)
        self.currentGram = self.gramFrom + (self.gramTo - self.gramFrom) * p
        self.contentView.bounds = CGRect(x: 0.0, y: 0.0, width: self.currentWidth, height: 26.0)
        if let glassBackgroundView = self.glassBackgroundView {
            glassBackgroundView.bounds = self.contentView.bounds
            glassBackgroundView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
            glassBackgroundView.update(
                size: self.contentView.bounds.size,
                cornerRadius: 13.0,
                isDark: self.isDark,
                tintColor: .init(kind: .panel),
                isInteractive: self.isEnabled,
                transition: .immediate
            )
            self.contentView.center = CGPoint(x: self.currentWidth * 0.5, y: 13.0)
            self.glassButton?.frame = self.contentView.bounds
        } else {
            self.contentView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        }
        self.canvas.isRenderingEnabled = self.visible && UIApplication.shared.applicationState == .active
        self.canvas.frame = CGRect(x: 0, y: 0, width: ceil(max(self.widthFrom, self.widthTo, self.currentWidth) / 64.0) * 64.0, height: 26.0)
        self.canvas.frameDuration = self.frameDuration
        self.canvas.update(sprites: self.motion.frame(at: now, frameDuration: self.frameDuration), isAnimating: self.motion.isAnimating(at: now))
        let usesMetal = self.canvas.isAvailable && self.canvas.hasFrame
        self.canvas.isHidden = !usesMetal
        self.title.view?.isHidden = usesMetal
        self.gramIcon.frame = CGRect(x: 8.0, y: 5.0, width: 16.0, height: 16.0)
        self.gramIcon.alpha = self.currentGram
        let raw = self.arrowTiming?.progress(at: now) ?? 1.0
        self.arrowPhase = self.arrowFrom + (self.arrowTo - self.arrowFrom) * WalletSendAmountMotionTiming.ease(raw)
        let phase = self.arrowPhase.truncatingRemainder(dividingBy: 1.0)
        let speed = pow(1.0 - raw, 1.2)
        self.arrowPace = self.arrowPaceFrom + (speed - self.arrowPaceFrom) * WalletSendAmountMotionTiming.ease(min(1.0, raw / 0.15))
        let pace: CGFloat = self.arrowTiming?.reduced == true ? 0.0 : self.arrowPace
        let loop = phase < 0.5 ? phase * 2.0 : phase * 2.0 - 2.0
        let smear = 8.0 * pace
        let multiple = smear > 1.0
        let weights: [CGFloat] = [0.45, 0.8625, 1.0, 0.8625, 0.45]
        for (i, arrow) in self.arrows.enumerated() {
            let sample = i % 5
            let direction: CGFloat = i < 5 ? -1.0 : 1.0
            let k: CGFloat = multiple ? CGFloat(sample) / 4.0 - 0.5 : 0.0
            arrow.transform = .identity
            arrow.frame = CGRect(x: self.currentWidth - 26.0, y: 4.0, width: 18.0, height: 18.0)
            let travel = self.arrowTiming?.reduced == true ? 0.0 : direction * (22.0 * loop + k * smear)
            arrow.transform = CGAffineTransform(translationX: 0.0, y: travel).scaledBy(x: 1.0, y: 1.0 + 0.55 * pace)
            arrow.alpha = multiple ? weights[sample] / 3.625 : (sample == 0 ? 1.0 : 0.0)
        }
        if !self.isAnimating {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
    }

    private func finishMotion() {
        self.motion.finish()
        self.geometryTiming = nil
        self.arrowTiming = nil
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.renderFrame()
    }
}
