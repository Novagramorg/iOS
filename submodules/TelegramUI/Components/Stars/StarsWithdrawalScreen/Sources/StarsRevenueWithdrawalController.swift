import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import PasswordSetupUI
import Markdown
import OwnershipTransferController
import AlertComponent

public func confirmStarsRevenueWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, amount: Int64, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    var proceedImpl: (() -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ChannelOwnershipTransferAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, title: presentationData.strings.Monetization_Withdraw_EnterPassword_Title, text: presentationData.strings.Monetization_Withdraw_EnterPassword_Text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Monetization_Withdraw_EnterPassword_Done, action: {
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
        
        let signal = context.engine.peers.requestStarsRevenueWithdrawalUrl(peerId: peerId, ton: false, amount: amount, password: contentNode.password)
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

public func starsRevenueWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, amount: Int64, initialError: RequestStarsRevenueWithdrawalError, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var title: String? = strings.OwnershipTransfer_SecurityCheck
    var text = strings.Monetization_Withdraw_SecurityRequirements

    var actions: [AlertScreen.Action] = [
        .init(title: strings.Common_OK, type: .default)
    ]
    switch initialError {
    case .requestPassword:
        return confirmStarsRevenueWithdrawalController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, amount: amount, present: present, completion: completion)
    case .twoStepAuthTooFresh, .authSessionTooFresh:
        text = text + strings.Monetization_Withdraw_ComeBackLater
    case .twoStepAuthMissing:
        actions = [
            .init(title: strings.OwnershipTransfer_SetupTwoStepAuth, type: .default, action: {
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
