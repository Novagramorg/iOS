import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import Markdown
import GiftItemComponent
import StarsAvatarComponent
import PasswordSetupUI
import OwnershipTransferController
import PresentationDataUtils
import AlertComponent
import AlertTransferHeaderComponent

public func giftWithdrawAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    commit: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertTransferHeaderComponent(
                fromComponent: AnyComponentWithIdentity(id: "gift", component: AnyComponent(
                    GiftItemComponent(
                        context: context,
                        theme: presentationData.theme,
                        strings: strings,
                        peer: nil,
                        subject: .uniqueGift(gift: gift, price: nil),
                        mode: .thumbnail
                    )
                )),
                toComponent: AnyComponentWithIdentity(id: "fragment", component: AnyComponent(
                    StarsAvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: .transactionPeer(.fragment),
                        photo: nil,
                        media: [],
                        gift: nil,
                        backgroundColor: .clear,
                        size: CGSize(width: 60.0, height: 60.0)
                    )
                )),
                type: .transfer
            )
        )
    ))
    
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Gift_Withdraw_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Gift_Withdraw_Text("\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))").string))
        )
    ))

    let alertController = AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        content: content,
        actions: [
            .init(title: strings.Gift_Withdraw_Proceed, type: .default, action: {
                commit()
            }),
            .init(title: strings.Common_Cancel)
        ]
    )
    return alertController
}

public func confirmGiftWithdrawalController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    reference: StarGiftReference,
    present: @escaping (ViewController, Any?) -> Void,
    completion: @escaping (String) -> Void
) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    var proceedImpl: (() -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ChannelOwnershipTransferAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, title: presentationData.strings.Gift_Withdraw_EnterPassword_Title, text: presentationData.strings.Gift_Withdraw_EnterPassword_Text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Withdraw_EnterPassword_Done, action: {
        proceedImpl?()
    })])
    
    contentNode.complete = {
        proceedImpl?()
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.theme = presentationData.theme
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
        disposable.dispose()
    }
    dismissImpl = { [weak controller, weak contentNode] in
        contentNode?.dismissInput()
        controller?.dismissAnimated()
    }
    proceedImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        contentNode.updateIsChecking(true)
        
        let signal = context.engine.payments.requestStarGiftWithdrawalUrl(reference: reference, password: contentNode.password)
        disposable.set((signal |> deliverOnMainQueue).start(next: { url in
            dismissImpl?()
            completion(url)
        }, error: { [weak contentNode] error in
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
                case .invalidPassword:
                    contentNode?.animateError()
                case .limitExceeded:
                    errorTextAndActions = (presentationData.strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                default:
                    errorTextAndActions = (presentationData.strings.Login_UnknownError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
            }
            contentNode?.updateIsChecking(false)
            
            if let (text, actions) = errorTextAndActions {
                dismissImpl?()
                present(textAlertController(context: context, title: nil, text: text, actions: actions), nil)
            }
        }))
    }
    
    return controller
}

public func giftWithdrawalController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    reference: StarGiftReference,
    initialError: RequestStarGiftWithdrawalError,
    present: @escaping (ViewController, Any?) -> Void,
    completion: @escaping (String) -> Void
) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var title: String? = strings.Gift_Withdraw_SecurityCheck
    var text = strings.Gift_Withdraw_SecurityRequirements
    
    var actions: [AlertScreen.Action] = [
        .init(title: strings.Common_OK, type: .default)
    ]
    switch initialError {
        case .requestPassword:
        return confirmGiftWithdrawalController(context: context, updatedPresentationData: updatedPresentationData, reference: reference, present: present, completion: completion)
        case .twoStepAuthTooFresh, .authSessionTooFresh:
            text = text + presentationData.strings.Gift_Withdraw_ComeBackLater
        case .twoStepAuthMissing:
            actions = [
                .init(title: strings.Gift_Withdraw_SetupTwoStepAuth, type: .default, action: {
                    let controller = SetupTwoStepVerificationController(context: context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                        if shouldDismiss {
                            controller.dismiss()
                        }
                    })
                    present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }),
                .init(title: strings.Common_Cancel)
            ]
        default:
            title = nil
            text = strings.Login_UnknownError
    }
    
    return AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        title: title,
        text: text,
        actions: actions
    )
}
