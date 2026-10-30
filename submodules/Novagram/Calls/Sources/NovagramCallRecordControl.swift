import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import NovagramLocalization

/// The "● Record" / "● REC 00:12" capsule at the top of the 1:1 call screen (HOOKS.md, "Call recording").
///
/// The call screen owns one and lays it out at the end of every layout pass (`update(host:…)`), after all of its
/// own elements have their frames. The call controller (TelegramCallsUI's `NovagramCallRecordingGlue`) drives what it
/// shows through `setState` and receives taps through `toggle`. This module knows nothing about calls or recording.
///
/// Placement: in the top row, centred on the screen when that spot is free; otherwise centred in the gap between the
/// back button and the next element to its right (the emoji key) when it fits; otherwise centred under the top
/// elements, moved down past whatever it would cover (emoji key, title, status, weak signal label, avatar).
public final class NovagramCallRecordControl: NSObject {
    private static let height: CGFloat = 28.0
    private static let sideInset: CGFloat = 11.0
    private static let dotSize: CGFloat = 8.0
    private static let dotSpacing: CGFloat = 6.0
    private static let spacing: CGFloat = 8.0
    private static let topRowOffset: CGFloat = 12.0
    private static let fontSize: CGFloat = 14.0
    private static let idleBackgroundAlpha: CGFloat = 0.45
    private static let recordingColor = UIColor(rgb: 0xff3b30)
    private static let tickInterval: Double = 0.5
    private static let stateTransitionDuration: Double = 0.2
    // An element taller than this share of the screen is the full-screen video, not something to keep clear of.
    private static let fullScreenShare: CGFloat = 0.5

    /// Called on a tap, both to start and to stop.
    public var toggle: (() -> Void)?

    private var isAvailable = false
    private var recordingStart: Double?

    private weak var host: UIView?
    private var insets = UIEdgeInsets()
    private var centerX: CGFloat = 0.0
    private weak var backButton: CALayer?
    private var avoiding: [NovagramWeakLayer] = []
    private var isHidden = false
    private var strings: NovagramL10n?

    private var button: HighlightableButton?
    private let dotView = UIView()
    private let label = UILabel()
    private var timer: Foundation.Timer?

    override public init() {
        super.init()
    }

    deinit {
        self.timer?.invalidate()
    }

    /// `isAvailable`: the control may show (recording is switched on or running, and the call is in a state that
    /// allows it). `recordingStart`: `CFAbsoluteTimeGetCurrent()` when the running recording started, nil when idle.
    public func setState(isAvailable: Bool, recordingStart: Double?) {
        if self.isAvailable == isAvailable && self.recordingStart == recordingStart {
            return
        }
        self.isAvailable = isAvailable
        self.recordingStart = recordingStart
        self.updateTimer()
        self.layout(transition: .easeInOut(duration: NovagramCallRecordControl.stateTransitionDuration))
    }

    /// From every layout pass of the call screen, after all of its elements have their frames.
    /// `avoiding`: the screen's elements the capsule must not cover (nil and invisible ones are skipped).
    public func update(host: UIView, insets: UIEdgeInsets, centerX: CGFloat, backButton: UIView, avoiding: [CALayer?], isHidden: Bool, strings: PresentationStrings, transition: ComponentTransition) {
        self.host = host
        self.insets = insets
        self.centerX = centerX
        self.backButton = backButton.layer
        self.avoiding = avoiding.compactMap { $0.flatMap(NovagramWeakLayer.init) }
        self.isHidden = isHidden
        self.strings = NovagramL10n(strings)
        self.layout(transition: transition)
    }

    // MARK: - Layout

    private func layout(transition: ComponentTransition) {
        guard self.isAvailable, !self.isHidden, let host = self.host, let strings = self.strings else {
            self.hideButton(transition: transition)
            return
        }

        let button: HighlightableButton
        let isNew: Bool
        if let current = self.button {
            button = current
            isNew = button.superview == nil
        } else {
            button = self.makeButton()
            self.button = button
            isNew = true
        }
        if button.superview !== host {
            host.addSubview(button)
        } else {
            // Stay above the screen's own elements (the screen adds some of them lazily).
            host.bringSubviewToFront(button)
        }
        button.isUserInteractionEnabled = true

        self.updateContent(strings: strings)
        let size = self.contentSize()
        let frame = self.placement(size: size, host: host)

        if isNew {
            button.frame = frame
            button.alpha = 0.0
        } else {
            transition.setFrame(view: button, frame: frame)
        }
        self.layoutContent(size: size)
        transition.setAlpha(view: button, alpha: 1.0)
    }

    private func makeButton() -> HighlightableButton {
        let button = HighlightableButton(frame: CGRect())
        button.layer.cornerRadius = NovagramCallRecordControl.height * 0.5
        button.clipsToBounds = true
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)

        self.dotView.layer.cornerRadius = NovagramCallRecordControl.dotSize * 0.5
        self.dotView.isUserInteractionEnabled = false
        button.addSubview(self.dotView)

        self.label.font = UIFont.monospacedDigitSystemFont(ofSize: NovagramCallRecordControl.fontSize, weight: .semibold)
        self.label.textColor = .white
        self.label.isUserInteractionEnabled = false
        button.addSubview(self.label)
        return button
    }

    private func updateContent(strings: NovagramL10n) {
        guard let button = self.button else {
            return
        }
        if let recordingStart = self.recordingStart {
            let elapsed = NovagramCallRecordControl.formatElapsed(CFAbsoluteTimeGetCurrent() - recordingStart)
            self.label.text = "\(strings.call_rec) \(elapsed)"
            button.backgroundColor = NovagramCallRecordControl.recordingColor
            self.dotView.backgroundColor = .white
            button.accessibilityLabel = strings.call_stopRecordingAccessibility
            button.accessibilityValue = "\(strings.call_rec) \(elapsed)"
        } else {
            self.label.text = strings.call_record
            button.backgroundColor = UIColor(white: 0.0, alpha: NovagramCallRecordControl.idleBackgroundAlpha)
            self.dotView.backgroundColor = NovagramCallRecordControl.recordingColor
            button.accessibilityLabel = strings.call_recordAccessibility
            button.accessibilityValue = nil
        }
    }

    private func contentSize() -> CGSize {
        let labelWidth = ceil(self.label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: NovagramCallRecordControl.height)).width)
        let width = NovagramCallRecordControl.sideInset * 2.0 + NovagramCallRecordControl.dotSize + NovagramCallRecordControl.dotSpacing + labelWidth
        return CGSize(width: width, height: NovagramCallRecordControl.height)
    }

    private func layoutContent(size: CGSize) {
        let dotFrame = CGRect(x: NovagramCallRecordControl.sideInset, y: floor((size.height - NovagramCallRecordControl.dotSize) * 0.5), width: NovagramCallRecordControl.dotSize, height: NovagramCallRecordControl.dotSize)
        self.dotView.frame = dotFrame
        let labelX = dotFrame.maxX + NovagramCallRecordControl.dotSpacing
        self.label.frame = CGRect(x: labelX, y: 0.0, width: max(0.0, size.width - labelX - NovagramCallRecordControl.sideInset), height: size.height)
    }

    private func placement(size: CGSize, host: UIView) -> CGRect {
        let spacing = NovagramCallRecordControl.spacing
        let backFrame = self.backButton.flatMap { self.visibleFrame(of: $0, in: host) }
        let obstacles = self.avoiding.compactMap { $0.layer.flatMap { self.visibleFrame(of: $0, in: host) } } + (backFrame.map { [$0] } ?? [])
        let isClear: (CGRect) -> Bool = { frame in
            let padded = frame.insetBy(dx: -spacing * 0.5, dy: -spacing * 0.5)
            return !obstacles.contains(where: { $0.intersects(padded) })
        }

        let rowY: CGFloat
        if let backFrame {
            rowY = floor(backFrame.midY - size.height * 0.5)
        } else {
            rowY = self.insets.top + NovagramCallRecordControl.topRowOffset
        }
        let centered = CGRect(x: floor(self.centerX - size.width * 0.5), y: rowY, width: size.width, height: size.height)
        if isClear(centered) {
            return centered
        }

        // Between the back button and the next element to its right (the emoji key while the call is active).
        let left = (backFrame?.maxX ?? self.insets.left) + spacing
        let rowBand = CGRect(x: left, y: rowY, width: max(0.0, host.bounds.width - left), height: size.height)
        let right = obstacles.filter { $0.intersects(rowBand) && $0.minX >= left }.map { $0.minX - spacing }.min() ?? (host.bounds.width - self.insets.right - spacing)
        if right - left >= size.width {
            let gap = CGRect(x: floor((left + right - size.width) * 0.5), y: rowY, width: size.width, height: size.height)
            if isClear(gap) {
                return gap
            }
        }

        // Under the top elements: move down past whatever it would cover.
        var frame = centered
        for _ in 0 ... obstacles.count {
            let padded = frame.insetBy(dx: -spacing * 0.5, dy: -spacing * 0.5)
            guard let lowest = obstacles.filter({ $0.intersects(padded) }).max(by: { $0.maxY < $1.maxY }) else {
                break
            }
            frame.origin.y = lowest.maxY + spacing
        }
        return frame
    }

    /// The layer's frame in `host`, from its model position and bounds (a running scale-in does not count),
    /// or nil when it shows nothing.
    private func visibleFrame(of layer: CALayer, in host: UIView) -> CGRect? {
        guard let superlayer = layer.superlayer, !layer.isHidden, layer.opacity > 0.01, !layer.bounds.isEmpty else {
            return nil
        }
        let origin = CGPoint(x: layer.position.x - layer.bounds.width * layer.anchorPoint.x, y: layer.position.y - layer.bounds.height * layer.anchorPoint.y)
        let frame = host.layer.convert(CGRect(origin: origin, size: layer.bounds.size), from: superlayer)
        if frame.maxY <= 0.0 || frame.height > host.bounds.height * NovagramCallRecordControl.fullScreenShare {
            return nil
        }
        return frame
    }

    private func hideButton(transition: ComponentTransition) {
        guard let button = self.button, button.superview != nil else {
            return
        }
        button.isUserInteractionEnabled = false
        transition.setAlpha(view: button, alpha: 0.0, completion: { [weak self, weak button] completed in
            guard completed, let self, let button, !self.isAvailable || self.isHidden else {
                return
            }
            button.removeFromSuperview()
        })
    }

    // MARK: - Timer

    private func updateTimer() {
        if self.recordingStart != nil && self.isAvailable {
            if self.timer == nil {
                self.timer = Foundation.Timer.scheduledTimer(withTimeInterval: NovagramCallRecordControl.tickInterval, repeats: true, block: { [weak self] _ in
                    self?.tick()
                })
            }
        } else {
            self.timer?.invalidate()
            self.timer = nil
        }
    }

    private func tick() {
        guard let strings = self.strings, let button = self.button, button.superview != nil else {
            return
        }
        let previousText = self.label.text
        self.updateContent(strings: strings)
        if self.label.text != previousText && self.contentSize().width != button.bounds.width {
            self.layout(transition: .immediate)
        }
    }

    static func formatElapsed(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    @objc private func buttonPressed() {
        self.toggle?()
    }
}

private final class NovagramWeakLayer {
    weak var layer: CALayer?

    init(_ layer: CALayer) {
        self.layer = layer
    }
}
