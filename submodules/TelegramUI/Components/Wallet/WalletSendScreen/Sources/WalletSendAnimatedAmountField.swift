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
                gramAlpha: self.gramAlpha + (other.gramAlpha - self.gramAlpha) * p
            )
        }
    }

    private let canvas = WalletSendAmountCanvas(frame: .zero)
    private let caretView = UIView()
    private let motion = WalletSendAmountMotion()
    private var displayLink: SharedDisplayLinkDriver.Link?
    private var previousMode: WalletSendInputMode?
    private var previousText = ""
    private var layoutFrom: Layout?
    private var layoutTo: Layout?
    private var currentLayout: Layout?
    private var visible = false
    private var updating = false
    private var rendering = false
    private var pendingDiamond = false
    private var placeholder: NSAttributedString?
    private var previousSelection: NSRange?
    private var availableWidth: CGFloat = 0.0
    private var frameDuration = 1.0 / 60.0
    private(set) var motionTiming: WalletSendAmountMotionTiming?

    override var usesAnimatedPresentation: Bool { return true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.canvas.isHidden = true
        self.contentView.addSubview(self.canvas)
        self.caretView.isUserInteractionEnabled = false
        self.caretView.accessibilityElementsHidden = true
        self.caretView.layer.cornerRadius = 1.0
        self.caretView.isHidden = true
        self.contentView.addSubview(self.caretView)
        self.textField.interactionBegan = { [weak self] in self?.finishMotion() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { self.displayLink?.invalidate() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil {
            self.pendingDiamond = false
            self.finishMotion()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.type == .touches, self.point(inside: point, with: event) {
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
        self.visible = isVisible
        super.update(mode: mode, amount: amount, rate: rate, fiatCurrency: fiatCurrency, dateTimeFormat: dateTimeFormat, theme: theme, lottieSettings: lottieSettings, isVisible: isVisible, transition: .immediate)
        self.placeholder = self.textField.attributedPlaceholder
        self.layoutIfNeeded()
        if !isVisible {
            self.pendingDiamond = false
            self.finishMotion()
        }
    }

    override func willApplyText(_ text: String, selection: NSRange?) {
        guard self.previousMode != nil, self.visible, self.window != nil else { return }
        self.textField.displaysNativeCaret = false
    }

    override func setAmount(_ amount: Int64) {
        super.setAmount(amount)
        if !self.updating { self.layoutIfNeeded() }
    }

    override func insertText(_ text: String) {
        super.insertText(text)
        self.layoutIfNeeded()
    }

    override func deleteBackward() {
        super.deleteBackward()
        self.layoutIfNeeded()
    }

    override func textFieldDidChangeSelection(_ textField: UITextField) {
        super.textFieldDidChangeSelection(textField)
        if !self.isApplyingText && !self.rendering && !self.updating,
           self.previousText == (textField.text ?? ""), self.previousSelection != self.textField.selectionRange {
            self.finishMotion()
        }
    }

    override func textFieldDidEndEditing(_ textField: UITextField) {
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
        let baseline = self.textField.frame.minY + (hasCaretGeometry ? caret.midY : textRect.midY) + (self.integralFont.ascender + self.integralFont.descender) / 2.0
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
        let selectedCaret = self.textField.selectedTextRange.map { self.textField.nativeCaretRect(for: $0.end) } ?? caret
        let targetLayout = Layout(
            width: self.contentView.bounds.width, height: self.contentView.bounds.height,
            gram: self.gramIcon.view?.frame ?? .zero, fiat: self.fiatIcon.view?.frame ?? .zero,
            caret: selectedCaret.offsetBy(dx: self.textField.frame.minX, dy: self.textField.frame.minY),
            gramAlpha: self.mode == .gram ? 1.0 : 0.0
        )
        let modeChanged = self.previousMode != nil && self.previousMode != self.mode
        let sizeChanged = self.availableWidth != self.bounds.width
        self.availableWidth = self.bounds.width
        if glyphs != self.motion.target {
            let mayAnimate = self.previousMode != nil && self.visible && self.window != nil && !sizeChanged && (self.textField.selectionRange?.length ?? 0) == 0
            let oldValue = Double(self.previousText.replacingOccurrences(of: decimal, with: ".")) ?? 0.0
            let newValue = Double(rawText.replacingOccurrences(of: decimal, with: ".")) ?? 0.0
            let timing = mayAnimate ? WalletSendAmountMotionTiming(spin: modeChanged, up: newValue >= oldValue, start: now) : nil
            self.layoutFrom = sourceLayout ?? targetLayout
            self.layoutTo = targetLayout
            self.motion.update(glyphs, timing: timing, at: now)
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
            (self.gramIcon.view as? LottieComponent.View)?.externalShouldPlay = false
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
        if !visible { self.textField.displaysNativeCaret = false }
        self.textField.rendersText = visible
        if let placeholder = self.placeholder {
            let text = NSMutableAttributedString(attributedString: placeholder)
            if !visible { text.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: text.length)) }
            self.textField.attributedPlaceholder = text
        }
        self.suffix.view?.alpha = visible ? 1.0 : 0.0
        self.canvas.isHidden = visible
        self.caretView.isHidden = visible || !self.isInputActive || (self.textField.selectionRange?.length ?? 0) != 0
        if visible {
            self.textField.layoutIfNeeded()
            self.textField.displaysNativeCaret = true
            self.textField.layoutIfNeeded()
        }
    }

    private func presentationLayout(at time: Double) -> Layout? {
        if let timing = self.motion.timing, let from = self.layoutFrom, let to = self.layoutTo {
            return from.interpolate(to: to, progress: WalletSendAmountMotionTiming.ease(timing.progress(at: time)))
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
            self.canvas.frame = CGRect(x: -32.0, y: -32.0, width: layout.width + 64.0, height: layout.height + 64.0)
            self.canvas.frameDuration = self.frameDuration
            self.canvas.sprites = self.motion.frame(at: now, frameDuration: self.frameDuration).map { sprite in
                var sprite = sprite
                sprite.glyph.position.x += 32.0
                sprite.glyph.position.y += 32.0
                return sprite
            }
            self.contentView.bringSubviewToFront(self.canvas)
            self.contentView.bringSubviewToFront(self.caretView)
            self.caretView.frame = layout.caret
            self.caretView.backgroundColor = self.textField.caretColor
        }
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
            ComponentTransition.immediate.setBlur(layer: view.layer, radius: reduced ? 0.0 : 6.0 * (1.0 - alpha))
        }
    }

    private func finishMotion() {
        let wasRendering = self.rendering
        self.rendering = true
        defer { self.rendering = wasRendering }
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.motion.finish()
        UIView.performWithoutAnimation {
            if let layout = self.layoutTo {
                self.currentLayout = layout
                self.apply(layout: layout, reduced: true)
                self.caretView.frame = layout.caret
            }
            self.setNativeTextVisible(true)
            if let selection = self.textField.selectedTextRange, var layout = self.currentLayout {
                layout.caret = self.textField.nativeCaretRect(for: selection.end).offsetBy(dx: self.textField.frame.minX, dy: self.textField.frame.minY)
                self.currentLayout = layout
                self.layoutTo = layout
            }
            self.previousSelection = self.textField.selectionRange
        }
        let diamond = self.gramIcon.view as? LottieComponent.View
        diamond?.externalShouldPlay = self.visible && self.mode == .gram
        if self.pendingDiamond {
            self.pendingDiamond = false
            if self.visible && self.mode == .gram && !UIAccessibility.isReduceMotionEnabled { diamond?.playOnce() }
        }
    }
}
