import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import ContextUI
import ItemListUI
import GlassBackgroundComponent
import NovagramLocalization
import NovagramVoiceChanger

/// Where the voice changer is opened from outside Settings (HOOKS.md, "Voice changer"): the button above the lock
/// while a voice message is recorded, the 1:1 call screen and the group call menu. As on Android, all of them open
/// the same list of effects, and only while the Developer switch is on.
public enum NovagramVoiceChangerUI {
    /// The SF Symbol for the voice changer: a person speaking, Android's "record_voice_over".
    public static let symbolName = "person.wave.2"

    /// Opens the effects page over the current screen. `onClose` runs once when it is gone.
    public static func presentPicker(context: AccountContext, forCall: Bool, present: (ViewController, Any?) -> Void, onClose: (() -> Void)? = nil) {
        let controller = novagramVoiceChangerController(context: context, forCall: forCall, asSheet: true)
        if let onClose, let listController = controller as? ItemListController {
            var didClose = false
            listController.didDisappear = { _ in
                if !didClose {
                    didClose = true
                    onClose()
                }
            }
        }
        present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }

    /// The voice-message button's tap. While a voice message is being recorded, the recording pauses first (the
    /// list would otherwise be recorded too) and goes on when the list closes, as on Android; the next part is
    /// recorded with the effect chosen. In the preview of a paused message the list just opens.
    public static func openFromRecording(context: AccountContext, isRecording: Bool, pause: () -> Void, resume: @escaping () -> Void, present: (ViewController, Any?) -> Void) {
        if isRecording {
            pause()
            self.presentPicker(context: context, forCall: false, present: present, onClose: {
                // The paused recording needs a moment to become a preview before it can go on.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: resume)
            })
        } else {
            self.presentPicker(context: context, forCall: false, present: present)
        }
    }

    /// The group call menu's row, or nil while the voice changer is off.
    public static func groupCallMenuItem(context: AccountContext, strings: PresentationStrings, present: @escaping (ViewController, Any?) -> Void) -> ContextMenuActionItem? {
        guard NovagramVoiceChanger.isEnabled else {
            return nil
        }
        let langCode = NovagramL10n.languageKey(for: strings)
        let choice = NovagramVoiceChanger.calls
        return ContextMenuActionItem(text: NovagramVoiceChangerStrings.title(langCode), textLayout: .secondLineWithValue(NovagramVoiceChangerStrings.presetName(choice.presetId, langCode)), icon: { theme in
            return generateTintedImage(image: UIImage(systemName: NovagramVoiceChangerUI.symbolName), color: theme.actionSheet.primaryTextColor)
        }, action: { _, f in
            f(.default)
            NovagramVoiceChangerUI.presentPicker(context: context, forCall: true, present: present)
        })
    }
}

/// The round button above the lock while a voice message is recorded (and in its preview), in the look of Telegram's
/// view-once button next to it. It shows only while the voice changer is on; the input panel lays it out with
/// `update` and handles the tap through `pressed`.
public final class NovagramVoiceChangerRecordButtonNode: HighlightTrackingButtonNode {
    private static let size = CGSize(width: 44.0, height: 44.0)
    private static let innerSize = CGSize(width: 40.0, height: 40.0)
    // Above the view-once button, one button height plus Telegram's spacing between those buttons.
    private static let offsetAboveViewOnce: CGFloat = 52.0

    public var pressed: (() -> Void)?

    private let backgroundView: GlassBackgroundView
    private let iconView: UIImageView
    private var theme: PresentationTheme?

    public init() {
        self.backgroundView = GlassBackgroundView()
        self.backgroundView.isUserInteractionEnabled = false
        self.iconView = UIImageView()

        super.init(pointerStyle: .default)

        self.view.addSubview(self.backgroundView)
        self.view.addSubview(self.iconView)
        self.accessibilityTraits = .button
        self.addTarget(self, action: #selector(self.onTap), forControlEvents: .touchUpInside)

        self.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            transition.updateAlpha(node: self, alpha: highlighted ? 0.6 : 1.0)
        }
    }

    @objc private func onTap() {
        self.pressed?()
    }

    /// From the input panel's layout. `viewOnceFrame`: where Telegram puts its view-once button; `isRecordingUIVisible`:
    /// Telegram shows that button (a locked voice recording or its preview); `viewOnceIsHidden`: the chat has no
    /// view-once (groups, channels, Saved Messages, bots), so this button takes its place instead of going above it.
    public func update(theme: PresentationTheme, strings: PresentationStrings, viewOnceFrame: CGRect, isRecordingUIVisible: Bool, viewOnceIsHidden: Bool, transition: ContainedViewLayoutTransition) {
        let size = NovagramVoiceChangerRecordButtonNode.size
        let innerSize = NovagramVoiceChangerRecordButtonNode.innerSize
        if self.theme !== theme {
            self.theme = theme
            self.iconView.image = generateTintedImage(image: UIImage(systemName: NovagramVoiceChangerUI.symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18.0, weight: .medium)), color: .white)?.withRenderingMode(.alwaysTemplate)
            self.iconView.tintColor = theme.chat.inputPanel.panelControlColor
        }
        self.accessibilityLabel = NovagramVoiceChangerStrings.title(NovagramL10n.languageKey(for: strings))

        let frame = CGRect(origin: CGPoint(x: viewOnceFrame.midX - size.width * 0.5, y: viewOnceFrame.minY - (viewOnceIsHidden ? 0.0 : NovagramVoiceChangerRecordButtonNode.offsetAboveViewOnce)), size: size)
        self.bounds = CGRect(origin: .zero, size: size)
        transition.updatePosition(node: self, position: CGPoint(x: frame.midX, y: frame.midY))

        let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - innerSize.width) * 0.5), y: floorToScreenPixels((size.height - innerSize.height) * 0.5)), size: innerSize)
        self.backgroundView.frame = backgroundFrame
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: .immediate)
        if let image = self.iconView.image {
            self.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) * 0.5), y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: image.size)
        }

        let isVisible = isRecordingUIVisible && NovagramVoiceChanger.isEnabled
        self.isUserInteractionEnabled = isVisible
        transition.updateAlpha(node: self, alpha: isVisible ? 1.0 : 0.0)
        transition.updateTransformScale(node: self, scale: isVisible ? 1.0 : 0.01)
    }
}
