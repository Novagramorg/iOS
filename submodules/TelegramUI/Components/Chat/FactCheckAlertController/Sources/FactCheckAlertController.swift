import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import TextFieldComponent
import ComponentDisplayAdapters
import TextFormat
import ComponentFlow
import AlertComponent
import AlertMultilineInputFieldComponent

public func factCheckAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    value: String,
    entities: [MessageTextEntity],
    apply: @escaping (String, [MessageTextEntity]) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
        
    let inputState = AlertMultilineInputFieldComponent.ExternalState()
    
    let doneIsEnabled: Signal<Bool, NoError>
    if !value.isEmpty {
        doneIsEnabled = .single(true)
    } else {
        doneIsEnabled = inputState.valueSignal
        |> map { value in
            return !value.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var characterLimit: Int = 1024
    if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["factcheck_length_limit"] as? Double {
        characterLimit = Int(value)
    }
    
    let initialValue = chatInputStateStringWithAppliedEntities(value, entities: entities)
    
    var presentImpl: ((ViewController) -> Void)?
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.FactCheck_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertMultilineInputFieldComponent(
                context: context,
                initialValue: initialValue,
                placeholder: strings.FactCheck_Placeholder,
                characterLimit: characterLimit,
                formatMenuAvailability: .available([.bold, .italic]),
                emptyLineHandling: .oneConsecutive,
                isInitiallyFocused: true,
                externalState: inputState,
                present: { c in
                    presentImpl?(c)
                }
            )
        )
    ))
    
    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }
    //FactCheck_Remove
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Common_Done, type: .default, action: {
                let (text, entities) = inputState.textAndEntities
                apply(text, entities)
            }, isEnabled: doneIsEnabled)
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    presentImpl = { [weak alertController] c in
        alertController?.present(c, in: .window(.root))
    }
    return alertController
}
