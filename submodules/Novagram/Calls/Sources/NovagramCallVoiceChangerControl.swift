import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import NovagramLocalization
import NovagramVoiceChanger

/// The voice changer's round button on the 1:1 call screen (HOOKS.md, "Voice changer"), as on Android's call screen.
///
/// The call screen owns one and lays it out at the end of every layout pass, after the Record control; the call
/// controller opens the effects list through `pressed`, and a choice applies to the call at once. Placement: at the
/// right edge of the back button's row, moved down past whatever it would cover (the emoji key while the call is
/// active). It hides with the screen's controls and shows only while the voice changer is on.
public final class NovagramCallVoiceChangerControl: NSObject {
    private static let size: CGFloat = 36.0
    private static let iconSize: CGFloat = 17.0
    private static let spacing: CGFloat = 8.0
    private static let sideInset: CGFloat = 16.0
    private static let backgroundAlpha: CGFloat = 0.45
    // An element taller than this share of the screen is the full-screen video, not something to keep clear of.
    private static let fullScreenShare: CGFloat = 0.5

    /// Called on a tap.
    public var pressed: (() -> Void)?

    private var button: HighlightableButton?
    private var isShown = false

    override public init() {
        super.init()
    }

    /// From every layout pass of the call screen. `avoiding`: the screen's elements the button must not cover.
    public func update(host: UIView, insets: UIEdgeInsets, backButton: UIView, avoiding: [CALayer?], controlsHidden: Bool, isEmojiKeyExpanded: Bool, isAnimatedOutToGroupCall: Bool, strings: PresentationStrings, transition: ComponentTransition) {
        let isVisible = NovagramVoiceChanger.isEnabled && !controlsHidden && !isEmojiKeyExpanded && !isAnimatedOutToGroupCall
        guard isVisible else {
            self.hide(transition: transition)
            return
        }
        let button: HighlightableButton
        let isNew: Bool
        if let current = self.button, current.superview === host {
            button = current
            isNew = !self.isShown
            host.bringSubviewToFront(button)
        } else {
            button = self.button ?? self.makeButton()
            self.button = button
            host.addSubview(button)
            isNew = true
        }
        button.accessibilityLabel = NovagramVoiceChangerTitle.title(NovagramL10n.languageKey(for: strings))
        button.isUserInteractionEnabled = true
        self.isShown = true

        let frame = self.placement(host: host, insets: insets, backButton: backButton, avoiding: avoiding)
        if isNew {
            button.frame = frame
            button.alpha = 0.0
        } else {
            transition.setFrame(view: button, frame: frame)
        }
        transition.setAlpha(view: button, alpha: 1.0)
    }

    private func makeButton() -> HighlightableButton {
        let size = NovagramCallVoiceChangerControl.size
        let button = HighlightableButton(frame: CGRect(x: 0.0, y: 0.0, width: size, height: size))
        button.backgroundColor = UIColor(white: 0.0, alpha: NovagramCallVoiceChangerControl.backgroundAlpha)
        button.layer.cornerRadius = size * 0.5
        button.clipsToBounds = true
        button.isAccessibilityElement = true
        button.accessibilityTraits = .button
        let configuration = UIImage.SymbolConfiguration(pointSize: NovagramCallVoiceChangerControl.iconSize, weight: .medium)
        button.setImage(UIImage(systemName: "person.wave.2", withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(self.onTap), for: .touchUpInside)
        return button
    }

    @objc private func onTap() {
        self.pressed?()
    }

    private func hide(transition: ComponentTransition) {
        guard self.isShown, let button = self.button else {
            return
        }
        self.isShown = false
        button.isUserInteractionEnabled = false
        transition.setAlpha(view: button, alpha: 0.0, completion: { [weak self, weak button] completed in
            guard completed, let self, let button, !self.isShown else {
                return
            }
            button.removeFromSuperview()
        })
    }

    private func placement(host: UIView, insets: UIEdgeInsets, backButton: UIView, avoiding: [CALayer?]) -> CGRect {
        let size = NovagramCallVoiceChangerControl.size
        let spacing = NovagramCallVoiceChangerControl.spacing
        let obstacles = avoiding.compactMap { $0.flatMap { self.visibleFrame(of: $0, in: host) } }
        let rowMidY = self.visibleFrame(of: backButton.layer, in: host)?.midY ?? (insets.top + 12.0 + size * 0.5)
        var frame = CGRect(x: host.bounds.width - insets.right - NovagramCallVoiceChangerControl.sideInset - size, y: floor(rowMidY - size * 0.5), width: size, height: size)
        for _ in 0 ... obstacles.count {
            let padded = frame.insetBy(dx: -spacing * 0.5, dy: -spacing * 0.5)
            guard let lowest = obstacles.filter({ $0.intersects(padded) }).max(by: { $0.maxY < $1.maxY }) else {
                break
            }
            frame.origin.y = lowest.maxY + spacing
        }
        return frame
    }

    /// The layer's frame in `host` from its model position and bounds, or nil when it shows nothing.
    private func visibleFrame(of layer: CALayer, in host: UIView) -> CGRect? {
        guard let superlayer = layer.superlayer, !layer.isHidden, layer.opacity > 0.01, !layer.bounds.isEmpty, layer !== self.button?.layer else {
            return nil
        }
        let origin = CGPoint(x: layer.position.x - layer.bounds.width * layer.anchorPoint.x, y: layer.position.y - layer.bounds.height * layer.anchorPoint.y)
        let frame = host.layer.convert(CGRect(origin: origin, size: layer.bounds.size), from: superlayer)
        if frame.maxY <= 0.0 || frame.height > host.bounds.height * NovagramCallVoiceChangerControl.fullScreenShare {
            return nil
        }
        return frame
    }
}

/// The button's accessibility name; the effects list itself (NovagramVoiceChangerUI) is opened by the call
/// controller, which this module can't depend on.
enum NovagramVoiceChangerTitle {
    static func title(_ langCode: String) -> String {
        switch langCode {
        case "uz": return "Ovoz o'zgartirgich"
        case "ru": return "Изменение голоса"
        case "zh": return "变声器"
        default: return "Voice changer"
        }
    }
}
