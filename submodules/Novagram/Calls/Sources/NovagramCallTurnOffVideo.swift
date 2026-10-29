import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import NovagramLocalization

/// "Turn off my video" under the 1:1 call screen's "Weak signal" label (HOOKS.md, "Call weak signal and data saver").
///
/// It shows once the label has been on screen for `showDelay` seconds in a row while our own camera video is on,
/// and goes away as soon as the label goes (the signal recovered) or our video goes off. Tapping it runs the
/// screen's camera button action, so it turns the video off exactly the way the camera button does.
/// The Mac's banner (`NovagramCallWeakNetwork`) uses the same 5 s delay and wording.
public final class NovagramCallTurnOffVideo: NSObject {
    private static let showDelay: Double = 5.0
    private static let spacing: CGFloat = 8.0
    private static let height: CGFloat = 30.0
    private static let sideInset: CGFloat = 12.0
    private static let fontSize: CGFloat = 15.0
    private static let backgroundAlpha: CGFloat = 0.45
    private static let appearDuration: Double = 0.2

    private weak var host: UIView?
    private weak var weakSignalView: UIView?
    private var isOwnVideoOn = false
    private var isHidden = false
    private var title = ""
    private var turnOffVideo: (() -> Void)?

    private var delayTimer: Foundation.Timer?
    private var isDelayOver = false
    private var button: HighlightableButton?

    override public init() {
        super.init()
    }

    deinit {
        self.delayTimer?.invalidate()
    }

    /// Called from every layout pass of the call screen. `weakSignalView` is the screen's "Weak signal" label,
    /// nil while it is not shown.
    public func update(host: UIView, weakSignalView: UIView?, isOwnVideoOn: Bool, isHidden: Bool, strings: PresentationStrings, transition: ComponentTransition, turnOffVideo: @escaping () -> Void) {
        self.host = host
        self.weakSignalView = weakSignalView
        self.isOwnVideoOn = isOwnVideoOn
        self.isHidden = isHidden
        self.title = NovagramL10n(strings).call_turnOffMyVideo
        self.turnOffVideo = turnOffVideo

        if weakSignalView == nil {
            // The signal recovered: the next weak spell waits the full delay again.
            self.delayTimer?.invalidate()
            self.delayTimer = nil
            self.isDelayOver = false
        } else if self.delayTimer == nil && !self.isDelayOver {
            self.delayTimer = Foundation.Timer.scheduledTimer(withTimeInterval: NovagramCallTurnOffVideo.showDelay, repeats: false, block: { [weak self] _ in
                guard let self else {
                    return
                }
                self.delayTimer = nil
                self.isDelayOver = true
                self.layout(transition: .easeInOut(duration: NovagramCallTurnOffVideo.appearDuration))
            })
        }

        self.layout(transition: transition)
    }

    private func layout(transition: ComponentTransition) {
        guard self.isDelayOver, self.isOwnVideoOn, !self.isHidden, let host = self.host, let weakSignalView = self.weakSignalView else {
            self.removeButton(transition: transition)
            return
        }

        let button: HighlightableButton
        let isNew: Bool
        if let current = self.button {
            button = current
            isNew = false
        } else {
            button = HighlightableButton(frame: CGRect())
            button.backgroundColor = UIColor(white: 0.0, alpha: NovagramCallTurnOffVideo.backgroundAlpha)
            button.layer.cornerRadius = NovagramCallTurnOffVideo.height * 0.5
            button.titleLabel?.font = Font.semibold(NovagramCallTurnOffVideo.fontSize)
            button.setTitleColor(.white, for: .normal)
            button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            self.button = button
            host.addSubview(button)
            isNew = true
        }
        if button.title(for: .normal) != self.title {
            button.setTitle(self.title, for: .normal)
        }

        // center + bounds, not frame: the label may still carry its appear scale transform.
        let maxWidth = max(0.0, host.bounds.width - 32.0)
        let titleWidth = ceil(button.titleLabel?.sizeThatFits(CGSize(width: maxWidth, height: NovagramCallTurnOffVideo.height)).width ?? 0.0)
        let width = min(maxWidth, titleWidth + NovagramCallTurnOffVideo.sideInset * 2.0)
        let labelMaxY = weakSignalView.center.y + weakSignalView.bounds.height * 0.5
        let frame = CGRect(x: floor(weakSignalView.center.x - width * 0.5), y: labelMaxY + NovagramCallTurnOffVideo.spacing, width: width, height: NovagramCallTurnOffVideo.height)

        if isNew {
            button.frame = frame
            button.alpha = 0.0
        } else {
            transition.setFrame(view: button, frame: frame)
        }
        transition.setAlpha(view: button, alpha: 1.0)
    }

    private func removeButton(transition: ComponentTransition) {
        guard let button = self.button else {
            return
        }
        self.button = nil
        transition.setAlpha(view: button, alpha: 0.0, completion: { [weak button] _ in
            button?.removeFromSuperview()
        })
    }

    @objc private func buttonPressed() {
        self.turnOffVideo?()
    }
}
