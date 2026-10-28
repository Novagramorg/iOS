import Foundation
import UIKit
import Display
import AppBundle
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import ContextUI
import UndoUI
import NovagramAds

/// "About this ad" / "Report" for OUR ads on every surface (contract §6). No Premium "Hide" item and
/// no "Remove ad" upsell: Novagram ads are shown to everyone and the server has no "hide" action.
public enum NovagramAdMenu {
    /// Context-menu items for OUR sponsored channel message, or nil for Telegram's own ads.
    public static func contextMenuItems(opaqueId: Data, context: AccountContext, present: @escaping (ViewController) -> Void) -> [ContextMenuItem]? {
        guard let token = NovagramSponsored.token(opaqueId: opaqueId) else {
            return nil
        }
        let strings = NovagramSponsoredStrings(context.sharedContext.currentPresentationData.with { $0 }.strings)

        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: strings.aboutAd, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
        }, action: { controller, _ in
            controller?.dismiss(completion: {
                self.presentAbout(token: token, context: context, present: present)
            })
        })))
        items.append(.action(ContextMenuActionItem(text: strings.reportAd, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
        }, action: { controller, _ in
            controller?.dismiss(completion: {
                self.presentReport(token: token, context: context, present: present)
            })
        })))
        return items
    }

    /// The About / Report sheet for OUR ad (bot panel long-press). Returns false for Telegram's own ads.
    public static func presentIfOurs(opaqueId: Data, context: AccountContext, present: @escaping (ViewController) -> Void) -> Bool {
        guard let token = NovagramSponsored.token(opaqueId: opaqueId) else {
            return false
        }
        self.presentSheet(token: token, context: context, present: present)
        return true
    }

    static func presentSheet(token: String, context: AccountContext, present: @escaping (ViewController) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = NovagramSponsoredStrings(presentationData.strings)
        let controller = ActionSheetController(presentationData: presentationData)
        let dismiss: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.aboutAd, color: .accent, action: {
                    dismiss()
                    self.presentAbout(token: token, context: context, present: present)
                }),
                ActionSheetButtonItem(title: strings.reportAd, color: .destructive, action: {
                    dismiss()
                    self.presentReport(token: token, context: context, present: present)
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.cancel, color: .accent, font: .bold, action: dismiss)
            ])
        ])
        present(controller)
    }

    static func presentAbout(token: String, context: AccountContext, present: @escaping (ViewController) -> Void) {
        let strings = NovagramSponsoredStrings(context.sharedContext.currentPresentationData.with { $0 }.strings)
        let otherInfo = NovagramSponsored.registry.served(token: token)?.ad.ad.otherInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        present(textAlertController(
            context: context,
            title: strings.aboutTitle,
            text: strings.aboutText(otherInfo: otherInfo),
            actions: [TextAlertAction(type: .defaultAction, title: strings.ok, action: {})]
        ))
    }

    /// Six reasons, then the ad is hidden and the user is thanked even if the report fails.
    static func presentReport(token: String, context: AccountContext, present: @escaping (ViewController) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = NovagramSponsoredStrings(presentationData.strings)
        let controller = ActionSheetController(presentationData: presentationData)
        let dismiss: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }

        var reasonItems: [ActionSheetItem] = [ActionSheetTextItem(title: strings.reportTitle)]
        for reason in SDKAdReportReason.allCases {
            reasonItems.append(ActionSheetButtonItem(title: strings.reason(reason), color: .accent, action: {
                dismiss()
                NovagramSponsored.report(token: token, reason: reason)
                present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .info(title: nil, text: strings.reportSent, timeout: nil, customUndoText: nil),
                    elevatedLayout: false,
                    action: { _ in
                        return false
                    }
                ))
            }))
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: reasonItems),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.cancel, color: .accent, font: .bold, action: dismiss)
            ])
        ])
        present(controller)
    }
}
