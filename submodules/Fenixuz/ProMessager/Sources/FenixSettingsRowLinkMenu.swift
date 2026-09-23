import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import FenixuzLocalization

// Feature #40 (part c): press and hold any settings row to copy or share a link that points
// straight at that row.
//
// The recognizer lives on the controller's own view rather than on each row: ItemList rows are
// built by upstream `ItemListUI` items we must not fork, and their nodes are recycled while
// scrolling, so a per-node recognizer would have to be re-attached on every layout pass.
enum FenixSettingsRowLinkMenu {
    /// `title` resolves the row's own label, so the sheet header names the setting the user
    /// actually pressed. Returning nil falls back to a generic header.
    static func attach(to controller: ItemListController, context: AccountContext, title: @escaping (FenixSettingsFeature) -> String?) {
        // A scroll that starts while the finger is still down must win over the press, or a slow
        // drag ends with an action sheet nobody asked for. The list tells us when that happens.
        let press = FenixSettingsRowPressState()
        controller.beganInteractiveDragging = { [weak press] in
            press?.didScroll = true
        }
        let recognizer = FenixSettingsRowLongPressGestureRecognizer(onBegan: { [weak press] in
            press?.didScroll = false
        }, onLongPress: { [weak controller, weak press] point in
            guard let controller, press?.didScroll == false else {
                return
            }
            guard let feature = Self.feature(at: point, in: controller) else {
                return
            }
            // The press already lit up the row; clear it, the sheet is the feedback now.
            controller.clearItemNodesHighlight(animated: true)
            Self.present(feature: feature, title: title(feature), context: context, controller: controller)
        })
        // The recognizer holds the state box, the view holds the recognizer — nothing else has to.
        recognizer.pressState = press
        controller.view.addGestureRecognizer(recognizer)
    }

    private static func feature(at point: CGPoint, in controller: ItemListController) -> FenixSettingsFeature? {
        let hostLayer = controller.view.layer
        var result: FenixSettingsFeature?
        controller.forEachItemNode { itemNode in
            guard result == nil else {
                return
            }
            guard let listItemNode = itemNode as? ItemListItemNode, let tag = listItemNode.tag as? FenixSettingsItemTag else {
                return
            }
            // Layer-space conversion, not view-space: some ItemList rows are layer-backed nodes
            // and touching their `view` would trip an AsyncDisplayKit assertion.
            let localPoint = itemNode.layer.convert(point, from: hostLayer)
            if itemNode.contentBounds.contains(localPoint) {
                result = tag.feature
            }
        }
        return result
    }

    private static func present(feature: FenixSettingsFeature, title: String?, context: AccountContext, controller: ViewController) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = FenixuzL10n.languageKey(for: presentationData.strings)
        let link = FenixSettingsDeepLink.link(for: feature)
        let header = title ?? FenixSettingsLinkStrings.menuTitle(langCode: langCode)

        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: "\(header)\n\(link)", parseMarkdown: false),
                ActionSheetButtonItem(title: FenixSettingsLinkStrings.copyLink(langCode: langCode), action: { [weak actionSheet, weak controller] in
                    actionSheet?.dismissAnimated()
                    UIPasteboard.general.string = link
                    controller?.present(
                        OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(FenixSettingsLinkStrings.copied(langCode: langCode), false)),
                        in: .window(.root)
                    )
                }),
                ActionSheetButtonItem(title: FenixSettingsLinkStrings.shareLink(langCode: langCode), action: { [weak actionSheet, weak controller] in
                    actionSheet?.dismissAnimated()
                    let shareController = context.sharedContext.makeShareController(
                        context: context,
                        params: ShareControllerParams(subject: .url(link))
                    )
                    controller?.present(shareController, in: .window(.root))
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        controller.present(actionSheet, in: .window(.root))
    }
}

/// Shared between the recognizer and the list's drag callback for the length of one press.
final class FenixSettingsRowPressState {
    var didScroll = false
}

/// Self-targeting long press that owns its callback, acts as its own delegate so it runs alongside
/// the list's scroll and selection gestures, and cancels the touch once it fires so the row
/// underneath does not also toggle.
///
/// The movement guard is written out by hand rather than left to `allowableMovement`: a drag that
/// crosses the threshold must fail the press even when it takes longer than `minimumPressDuration`,
/// otherwise a slow scroll ends with an action sheet in the user's face.
private final class FenixSettingsRowLongPressGestureRecognizer: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    private static let pressDuration: TimeInterval = 0.45
    private static let movementThreshold: CGFloat = 12.0

    private let onBegan: () -> Void
    private let onLongPress: (CGPoint) -> Void
    private var startPoint: CGPoint?
    /// Kept alive here so the caller does not need a field for it.
    var pressState: FenixSettingsRowPressState?

    init(onBegan: @escaping () -> Void, onLongPress: @escaping (CGPoint) -> Void) {
        self.onBegan = onBegan
        self.onLongPress = onLongPress
        super.init(target: nil, action: nil)
        self.minimumPressDuration = Self.pressDuration
        self.allowableMovement = Self.movementThreshold
        self.cancelsTouchesInView = true
        self.delegate = self
        self.addTarget(self, action: #selector(self.handleLongPress))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        self.startPoint = touches.first?.location(in: self.view)
        self.onBegan()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        // Only .possible may transition to .failed; once the press has begun the menu is already up
        // and UIKit rejects the transition.
        guard self.state == .possible, let startPoint = self.startPoint, let point = touches.first?.location(in: self.view) else {
            return
        }
        let distance = abs(point.x - startPoint.x) + abs(point.y - startPoint.y)
        if distance > Self.movementThreshold {
            self.state = .failed
        }
    }

    override func reset() {
        super.reset()
        self.startPoint = nil
    }

    @objc private func handleLongPress() {
        guard self.state == .began, let view = self.view else {
            return
        }
        self.onLongPress(self.location(in: view))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
