import Foundation
import UIKit
import Display
import ComponentFlow
import LottieComponent
import LottieSettings
import TelegramPresentationData
import WalletContext

func walletSendAmountComponentGlyphs(_ view: UIView, origin: CGPoint) -> [WalletSendAmountGlyph] {
    return view.subviews.sorted { $0.frame.minX < $1.frame.minX }.flatMap { child -> [WalletSendAmountGlyph] in
        guard let textView = child as? TextView, let layout = textView.cachedLayout,
              let text = layout.attributedString, let line = layout.linesRects().first else { return [] }
        return WalletSendAmountGlyph.text(text, origin: CGPoint(x: origin.x + child.frame.minX + line.minX, y: origin.y + child.frame.minY + line.minY), group: .suffix)
    }
}

final class WalletSendAnimatedAmountField: WalletSendAmountField {
    private struct Layout {
        var width: CGFloat
        var height: CGFloat
        var gram: CGRect
        var fiat: CGRect
        var caret: CGRect
        var gramAlpha: CGFloat

        func interpolate(to other: Layout, progress p: CGFloat) -> Layout {
            return Layout(
                width: self.width + (other.width - self.width) * p,
                height: self.height + (other.height - self.height) * p,
                gram: walletSendAmountMotionRect(self.gram, other.gram, p),
                fiat: walletSendAmountMotionRect(self.fiat, other.fiat, p),
                caret: walletSendAmountMotionRect(self.caret, other.caret, p),
                gramAlpha: self.gramAlpha + (other.gramAlpha - self.gramAlpha) * min(1.0, max(0.0, p))
            )
        }
    }

    private let canvas = WalletSendAmountCanvas(frame: .zero)
    private let caretView = UIView()
    private static let caretBlinkAnimationKey = "walletSendCaretBlink"
    private static let inputRefusalAnimationKey = "walletSendInputRefusal"
    private let hapticFeedback = HapticFeedback()
    private let motion = WalletSendAmountMotion(liquid: true)
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var previousMode: WalletSendInputMode?
    private var previousText = ""
    private var layoutFrom: Layout?
    private var layoutTo: Layout?
    private var currentLayout: Layout?
    private var visible = false
    private var applicationIsActive = UIApplication.shared.applicationState == .active
    private var updating = false
    private var rendering = false
    private var nativeInteraction = false
    private var pendingDiamond = false
    private var placeholder: NSAttributedString?
    private var previousSelection: NSRange?
    private var availableWidth: CGFloat = 0.0
    private var frameDuration = 1.0 / 120.0
    private(set) var motionTiming: WalletSendAmountMotionTiming?

    override var usesAnimatedPresentation: Bool { return true }

    override var isUserInteractionEnabled: Bool {
        didSet {
            if !self.isUserInteractionEnabled {
                self.stopInputRefusal()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.canvas.isHidden = true
        self.canvas.onFrameReady = { [weak self] in
            guard let self, self.visible, self.applicationIsActive, self.window != nil, !self.nativeInteraction else { return }
            self.setNativeTextVisible(false)
            self.textField.displaysNativeCaret = !self.motion.isAnimating(at: CACurrentMediaTime())
        }
        self.contentView.addSubview(self.canvas)
        self.caretView.isUserInteractionEnabled = false
        self.caretView.accessibilityElementsHidden = true
        self.caretView.layer.cornerRadius = 1.5
        self.caretView.isHidden = true
        self.contentView.addSubview(self.caretView)
        self.textField.usesCustomCaret = true
        self.textField.interactionBegan = { [weak self] in
            self?.nativeInteraction = true
            self?.finishMotion()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        self.displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil {
            self.stopInputRefusal()
            self.stopDiamond(at: .end)
            self.finishMotion()
        } else {
            self.setNeedsLayout()
        }
    }

    @objc private func applicationDidBecomeActive() {
        self.applicationIsActive = true
        self.setNeedsLayout()
        self.updateCaretAppearance()
    }

    @objc private func applicationWillResignActive() {
        self.applicationIsActive = false
        self.stopInputRefusal()
        self.canvas.isRenderingEnabled = false
        self.stopDiamond(at: .end)
        self.finishMotion()
    }

    @objc private func reduceMotionChanged() {
        if UIAccessibility.isReduceMotionEnabled {
            self.layer.removeAnimation(forKey: Self.inputRefusalAnimationKey)
        }
        self.finishMotion()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.type == .touches, self.point(inside: point, with: event) {
            self.nativeInteraction = true
            self.finishMotion()
        }
        return super.hitTest(point, with: event)
    }

    override func update(
        mode: WalletSendInputMode, amount: Int64, rate: Double?, fiatCurrency: WalletContext.FiatCurrency,
        dateTimeFormat: PresentationDateTimeFormat, theme: PresentationTheme,
        lottieSettings: LottieRenderingSettings, isVisible: Bool, transition: ComponentTransition
    ) {
        self.updating = true
        defer { self.updating = false }
        let previousCaretColor = self.caretView.layer.presentation()?.backgroundColor ?? self.caretView.layer.backgroundColor
        let modeChanged = mode != self.mode
        if modeChanged {
            self.stopDiamond(at: mode == .gram ? .begin : nil)
        }
        if !isVisible {
            self.stopInputRefusal()
            self.stopDiamond(at: .end)
        }
        self.visible = isVisible
        self.canvas.prepareGlyphs(separators: dateTimeFormat.decimalSeparator + dateTimeFormat.groupingSeparator, currencyCode: fiatCurrency.code)
        self.canvas.isRenderingEnabled = isVisible && self.applicationIsActive
        super.update(mode: mode, amount: amount, rate: rate, fiatCurrency: fiatCurrency, dateTimeFormat: dateTimeFormat, theme: theme, lottieSettings: lottieSettings, isVisible: isVisible, transition: .immediate)
        self.placeholder = self.textField.attributedPlaceholder
        self.layoutIfNeeded()
        if modeChanged, isVisible, self.window != nil, let previousCaretColor, let timing = self.motionTiming {
            let animation = CABasicAnimation(keyPath: "backgroundColor")
            animation.fromValue = previousCaretColor
            animation.toValue = self.textField.caretColor.cgColor
            animation.duration = timing.duration
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.8, 0.45, 1.0)
            self.caretView.layer.add(animation, forKey: "backgroundColor")
        }
        if !isVisible {
            self.pendingDiamond = false
            self.finishMotion()
        }
    }

    override func willApplyText(_ text: String, selection: NSRange?) {
        if text != (self.textField.text ?? "") || (selection != nil && selection != self.textField.selectionRange) {
            self.nativeInteraction = false
            self.resetCaretBlink()
        }
        guard self.previousMode != nil, self.visible, self.window != nil else { return }
        self.textField.displaysNativeCaret = false
    }

    override func setAmount(_ amount: Int64) {
        super.setAmount(amount)
        if !self.updating { self.layoutIfNeeded() }
    }

    @discardableResult
    override func insertText(_ text: String) -> Bool {
        let accepted = super.insertText(text)
        if accepted { self.layoutIfNeeded() }
        return accepted
    }

    @discardableResult
    override func deleteBackward() -> Bool {
        let accepted = super.deleteBackward()
        if accepted { self.layoutIfNeeded() }
        return accepted
    }

    override func inputRejected() {
        guard self.visible, self.applicationIsActive, self.window != nil,
              self.isUserInteractionEnabled, self.isInputActive else { return }
        
        self.hapticFeedback.impact(.rigid, intensity: 0.8)
        self.hapticFeedback.prepareImpact(.rigid)
        let secondImpact = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.visible, self.applicationIsActive, self.window != nil,
                  self.isUserInteractionEnabled, self.isInputActive else { return }
            self.hapticFeedback.impact(.rigid, intensity: 0.55)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: secondImpact)

        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        let initialOffset: CGFloat
        if self.layer.animation(forKey: Self.inputRefusalAnimationKey) != nil {
            initialOffset = (self.layer.presentation()?.transform.m41 ?? self.layer.transform.m41) - self.layer.transform.m41
        } else {
            initialOffset = 0.0
        }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = (0 ... 60).map { step -> NSNumber in
            let t = CGFloat(step) / 60.0
            let carry = max(0.0, 1.0 - 6.0 * t)
            let x = 9.0 * sin(6.0 * .pi * t) * (1.0 - t) + initialOffset * carry * carry
            return NSNumber(value: Double(x))
        }
        animation.duration = 0.42
        animation.calculationMode = .linear
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isAdditive = true
        self.layer.add(animation, forKey: Self.inputRefusalAnimationKey)
    }

    private func stopInputRefusal() {
        self.layer.removeAnimation(forKey: Self.inputRefusalAnimationKey)
    }

    override func textFieldDidChangeSelection(_ textField: UITextField) {
        super.textFieldDidChangeSelection(textField)
        if !self.isApplyingText && !self.rendering && !self.updating,
           self.previousText == (textField.text ?? ""), self.previousSelection != self.textField.selectionRange {
            self.nativeInteraction = true
            self.resetCaretBlink()
            self.finishMotion()
        }
    }

    override func textFieldDidBeginEditing(_ textField: UITextField) {
        super.textFieldDidBeginEditing(textField)
        self.resetCaretBlink()
        self.finishMotion()
    }

    override func textFieldDidEndEditing(_ textField: UITextField) {
        self.stopInputRefusal()
        self.finishMotion()
        super.textFieldDidEndEditing(textField)
    }

    override func layoutSubviews() {
        guard !self.rendering else { return }
        self.rendering = true
        defer { self.rendering = false }
        let now = CACurrentMediaTime()
        let sourceLayout = self.presentationLayout(at: now)
        self.gramIcon.view?.transform = .identity
        self.fiatIcon.view?.transform = .identity
        super.layoutSubviews()
        guard self.dateTimeFormat != nil else { return }

        let rawText = self.textField.text ?? ""
        let textLayout = self.amountTextLayout(rawText.isEmpty ? "0" : rawText)
        let attributedText = rawText.isEmpty ? (self.placeholder ?? textLayout.attributedText) : textLayout.attributedText
        self.textField.layoutIfNeeded()
        let caret = self.textField.nativeCaretRect(for: self.textField.beginningOfDocument)
        let hasCaretGeometry = !caret.isNull && !caret.isInfinite && caret.height > 0.0
        let textRect = self.textField.isEditing ? self.textField.editingRect(forBounds: self.textField.bounds) : self.textField.textRect(forBounds: self.textField.bounds)
        let baseline = self.textField.frame.minY + self.textField.amountTextBaseline(font: self.integralFont)
        let origin = CGPoint(x: self.textField.frame.minX + (hasCaretGeometry ? caret.minX : textRect.minX), y: baseline)
        var glyphs = WalletSendAmountGlyph.text(attributedText, origin: origin, group: .integer)
        let decimal = self.dateTimeFormat?.decimalSeparator ?? "."
        let fractionOffset = (attributedText.string as NSString).range(of: decimal).location
        var offset = 0
        for i in glyphs.indices {
            if fractionOffset != NSNotFound && offset >= fractionOffset { glyphs[i].group = .fraction }
            offset += glyphs[i].text.utf16.count
        }
        for position in textLayout.groupingPositions {
            glyphs += WalletSendAmountGlyph.text(textLayout.groupingSeparator, origin: CGPoint(x: origin.x + position - textLayout.groupingSeparatorSize.width, y: baseline), group: .grouping)
        }
        if let suffixView = self.suffix.view {
            glyphs += walletSendAmountComponentGlyphs(suffixView, origin: suffixView.frame.origin)
        }
        let selectedCaret = self.textField.amountCaretRect(for: self.textField.selectedTextRange?.end ?? self.textField.beginningOfDocument)
        let targetLayout = Layout(
            width: self.contentView.bounds.width, height: self.contentView.bounds.height,
            gram: self.gramIcon.view?.frame ?? .zero, fiat: self.fiatIcon.view?.frame ?? .zero,
            caret: selectedCaret.offsetBy(dx: self.textField.frame.minX, dy: self.textField.frame.minY),
            gramAlpha: self.mode == .gram ? 1.0 : 0.0
        )
        let modeChanged = self.previousMode != nil && self.previousMode != self.mode
        if modeChanged {
            self.resetCaretBlink()
        }
        let sizeChanged = self.availableWidth != self.bounds.width
        self.availableWidth = self.bounds.width
        if glyphs != self.motion.target {
            // Focus and initial layout can refine positions without changing
            // the amount. Only content changes should start a glyph transition.
            let contentChanged = self.previousText != rawText || modeChanged || glyphs.count != self.motion.target.count
                || zip(glyphs, self.motion.target).contains { lhs, rhs in
                    lhs.text != rhs.text || lhs.font != rhs.font || lhs.color != rhs.color || lhs.group != rhs.group
                }
            let mayAnimate = contentChanged && self.previousMode != nil && self.visible && self.applicationIsActive && self.window != nil && self.canvas.isAvailable && !sizeChanged && (self.textField.selectionRange?.length ?? 0) == 0
            let oldValue = Double(self.previousText.replacingOccurrences(of: decimal, with: ".")) ?? 0.0
            let newValue = Double(rawText.replacingOccurrences(of: decimal, with: ".")) ?? 0.0
            let timing = mayAnimate ? WalletSendAmountMotionTiming(spin: modeChanged, up: newValue >= oldValue, start: now) : nil
            self.layoutFrom = sourceLayout ?? targetLayout
            self.layoutTo = targetLayout
            self.motion.update(glyphs, width: targetLayout.width, timing: timing, at: now, frameDuration: self.frameDuration,
                fromPlaceholder: self.previousText.isEmpty && !rawText.isEmpty && !modeChanged)
            self.motionTiming = timing
            if modeChanged { self.pendingDiamond = self.mode == .gram && mayAnimate }
        } else if self.previousSelection != self.textField.selectionRange {
            self.motion.finish()
        }
        self.previousText = rawText
        self.previousMode = self.mode
        self.previousSelection = self.textField.selectionRange
        if self.motion.isAnimating(at: now), self.visible, !sizeChanged {
            self.textField.displaysNativeCaret = false
            self.renderFrame(at: now)
            self.setNativeTextVisible(false)
            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] duration in
                    guard let self else { return }
                    self.frameDuration += (Double(duration) - self.frameDuration) * 0.3
                    self.renderFrame()
                })
            }
        } else {
            self.layoutTo = targetLayout
            self.currentLayout = targetLayout
            self.finishMotion()
        }
    }

    private func setNativeTextVisible(_ visible: Bool) {
        let wasRendering = self.rendering
        self.rendering = true
        defer { self.rendering = wasRendering }
        let visible = visible || !self.canvas.isAvailable || !self.canvas.hasFrame
        if !visible { self.textField.displaysNativeCaret = false }
        self.textField.rendersText = visible
        if let placeholder = self.placeholder {
            let text = NSMutableAttributedString(attributedString: placeholder)
            if !visible { text.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: text.length)) }
            self.textField.attributedPlaceholder = text
        }
        self.suffix.view?.alpha = visible ? 1.0 : 0.0
        self.canvas.isHidden = visible
        if visible {
            self.textField.layoutIfNeeded()
            self.textField.displaysNativeCaret = true
            self.textField.layoutIfNeeded()
        }
    }

    private func presentationLayout(at time: Double) -> Layout? {
        if let timing = self.motion.timing, let from = self.layoutFrom, let to = self.layoutTo {
            var layout = from.interpolate(to: to, progress: timing.layoutProgress(at: time))
            layout.width += self.motion.widthAdjustment(at: time)
            layout.caret.origin.x = self.motion.caretPosition(at: time, fromX: from.caret.midX, toX: to.caret.midX) - layout.caret.width / 2.0
            return layout
        }
        return self.currentLayout
    }

    private func renderFrame(at now: Double = CACurrentMediaTime()) {
        guard self.motion.isAnimating(at: now), let timing = self.motion.timing, let layout = self.presentationLayout(at: now) else {
            self.finishMotion()
            return
        }
        self.currentLayout = layout
        UIView.performWithoutAnimation {
            self.apply(layout: layout, reduced: timing.reduced)
            self.drawText(layout: layout, at: now)
            self.contentView.bringSubviewToFront(self.canvas)
            self.contentView.bringSubviewToFront(self.caretView)
            self.updateCaretAppearance()
        }
    }

    private func drawText(layout: Layout, at now: Double) {
        self.canvas.isRenderingEnabled = self.visible && self.applicationIsActive
        // Keep the drawable size fixed throughout a transition; centering is
        // owned by contentView, so no GPU surface needs resizing every frame.
        let width = ceil(max(self.bounds.width, layout.width, self.layoutFrom?.width ?? 0, self.layoutTo?.width ?? 0) / 64.0) * 64.0
        self.canvas.frame = CGRect(x: -32.0, y: -32.0, width: width + 64.0, height: layout.height + 64.0)
        self.canvas.frameDuration = self.frameDuration
        let sprites = self.motion.frame(at: now, frameDuration: self.frameDuration).map { sprite in
            var sprite = sprite
            sprite.glyph.position.x += 32.0
            sprite.glyph.position.y += 32.0
            return sprite
        }
        self.canvas.update(sprites: sprites, isAnimating: self.motion.isAnimating(at: now))
    }

    private func resetCaretBlink() {
        self.caretView.layer.removeAnimation(forKey: Self.caretBlinkAnimationKey)
    }

    private func updateCaretAppearance() {
        guard self.visible, self.applicationIsActive, self.window != nil, self.isInputActive,
              self.textField.selectionRange?.length == 0, let layout = self.currentLayout,
              !layout.caret.isNull, !layout.caret.isInfinite, layout.caret.height > 0.0 else {
            self.caretView.isHidden = true
            self.resetCaretBlink()
            return
        }
        self.caretView.frame = layout.caret
        self.caretView.backgroundColor = self.textField.caretColor
        self.caretView.isHidden = false
        self.contentView.bringSubviewToFront(self.caretView)
        guard self.caretView.layer.animation(forKey: Self.caretBlinkAnimationKey) == nil else { return }

        let hold = 0.45
        let fade = 0.42
        let duration = (hold + fade) * 2.0
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1.0, 1.0, 0.0, 0.0, 1.0]
        animation.keyTimes = [0.0, hold / duration, (hold + fade) / duration, (hold * 2.0 + fade) / duration, 1.0].map { NSNumber(value: $0) }
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        animation.duration = duration
        animation.repeatCount = .infinity
        self.caretView.layer.add(animation, forKey: Self.caretBlinkAnimationKey)
    }

    private func apply(layout: Layout, reduced: Bool) {
        self.contentView.bounds = CGRect(x: 0.0, y: 0.0, width: layout.width, height: layout.height)
        self.contentView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        let scale = min(1.0, self.bounds.width / max(1.0, layout.width))
        self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
        for (view, rect, alpha) in [(self.gramIcon.view, layout.gram, layout.gramAlpha), (self.fiatIcon.view, layout.fiat, 1.0 - layout.gramAlpha)] {
            guard let view else { continue }
            view.transform = .identity
            view.frame = rect
            view.alpha = alpha
            let iconScale = reduced ? 1.0 : 0.7 + 0.3 * alpha
            view.transform = CGAffineTransform(scaleX: iconScale, y: iconScale)
            ComponentTransition.immediate.setBlur(layer: view.layer, radius: reduced ? 0.0 : 5.0 * (1.0 - alpha))
        }
    }

    private func stopDiamond(at position: LottieComponent.StartingPosition? = nil) {
        self.pendingDiamond = false
        let diamond = self.gramIcon.view as? LottieComponent.View
        diamond?.externalShouldPlay = false
        diamond?.stop(at: position)
    }

    private func finishMotion() {
        let wasRendering = self.rendering
        self.rendering = true
        defer { self.rendering = wasRendering }
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.motion.finish()
        if !self.visible || self.window == nil || !self.applicationIsActive {
            self.caretView.layer.removeAnimation(forKey: "backgroundColor")
        }
        UIView.performWithoutAnimation {
            if let layout = self.layoutTo {
                self.currentLayout = layout
                self.apply(layout: layout, reduced: true)
                self.caretView.frame = layout.caret
            }
            if let layout = self.currentLayout, self.visible, self.applicationIsActive, self.window != nil {
                self.drawText(layout: layout, at: CACurrentMediaTime())
            }
            self.setNativeTextVisible(self.nativeInteraction || !self.visible || !self.applicationIsActive)
            self.textField.displaysNativeCaret = true
            if let selection = self.textField.selectedTextRange, var layout = self.currentLayout {
                layout.caret = self.textField.amountCaretRect(for: selection.end).offsetBy(dx: self.textField.frame.minX, dy: self.textField.frame.minY)
                self.currentLayout = layout
                self.layoutTo = layout
            }
            self.previousSelection = self.textField.selectionRange
            self.updateCaretAppearance()
        }
        let diamond = self.gramIcon.view as? LottieComponent.View
        let canPlayDiamond = self.visible && self.window != nil && self.applicationIsActive
            && self.mode == .gram && !UIAccessibility.isReduceMotionEnabled
        diamond?.externalShouldPlay = canPlayDiamond
        if self.pendingDiamond {
            self.pendingDiamond = false
            if canPlayDiamond { diamond?.playOnce() }
        }
    }
}
