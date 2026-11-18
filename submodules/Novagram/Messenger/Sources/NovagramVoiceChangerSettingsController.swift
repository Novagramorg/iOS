import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import NovagramLocalization
import NovagramVoiceChanger
import NovagramVoiceChangerUI

// The Voice changer page, opened from its one public row in Novagram settings. Like the Call recording page,
// the enable switch lives here with its own explanation, and the two effect pages (voice messages, calls) open
// from their own rows that appear only while the switch is on.

private final class NovagramVoiceChangerSettingsArguments {
    let updateEnabled: (Bool) -> Void
    let openMessages: () -> Void
    let openCalls: () -> Void

    init(updateEnabled: @escaping (Bool) -> Void, openMessages: @escaping () -> Void, openCalls: @escaping () -> Void) {
        self.updateEnabled = updateEnabled
        self.openMessages = openMessages
        self.openCalls = openCalls
    }
}

private enum NovagramVoiceChangerSettingsSection: Int32 {
    case enable
    case effects
}

private enum NovagramVoiceChangerSettingsEntry: ItemListNodeEntry {
    case enable(PresentationTheme, String, Bool)
    case enableFooter(PresentationTheme, String)
    case messages(PresentationTheme, String, String)
    case messagesFooter(PresentationTheme, String)
    case calls(PresentationTheme, String, String)
    case callsFooter(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .enable, .enableFooter:
            return NovagramVoiceChangerSettingsSection.enable.rawValue
        case .messages, .messagesFooter, .calls, .callsFooter:
            return NovagramVoiceChangerSettingsSection.effects.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enable:         return 0
        case .enableFooter:   return 1
        case .messages:       return 2
        case .messagesFooter: return 3
        case .calls:          return 4
        case .callsFooter:    return 5
        }
    }

    static func == (lhs: NovagramVoiceChangerSettingsEntry, rhs: NovagramVoiceChangerSettingsEntry) -> Bool {
        switch lhs {
        case let .enable(lhsTheme, lhsTitle, lhsValue):
            if case let .enable(rhsTheme, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsValue == rhsValue { return true } else { return false }
        case let .enableFooter(lhsTheme, lhsText):
            if case let .enableFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .messages(lhsTheme, lhsTitle, lhsLabel):
            if case let .messages(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .messagesFooter(lhsTheme, lhsText):
            if case let .messagesFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .calls(lhsTheme, lhsTitle, lhsLabel):
            if case let .calls(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .callsFooter(lhsTheme, lhsText):
            if case let .callsFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        }
    }

    static func < (lhs: NovagramVoiceChangerSettingsEntry, rhs: NovagramVoiceChangerSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramVoiceChangerSettingsArguments
        switch self {
        case let .enable(_, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateEnabled(value)
            })
        case let .messages(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "mic.circle.fill", color: .blue), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openMessages()
            }, tag: NovagramSettingsItemTag(feature: .voiceChangerMessages))
        case let .calls(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "phone.circle.fill", color: .green), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openCalls()
            }, tag: NovagramSettingsItemTag(feature: .voiceChangerCalls))
        case let .enableFooter(_, text), let .messagesFooter(_, text), let .callsFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct NovagramVoiceChangerSettingsState: Equatable {
    var isEnabled: Bool
    var messagesPreset: Int
    var callsPreset: Int

    static func current() -> NovagramVoiceChangerSettingsState {
        return NovagramVoiceChangerSettingsState(isEnabled: NovagramVoiceChanger.isEnabled, messagesPreset: NovagramVoiceChanger.messages.presetId, callsPreset: NovagramVoiceChanger.calls.presetId)
    }
}

private func novagramVoiceChangerSettingsEntries(presentationData: PresentationData, state: NovagramVoiceChangerSettingsState) -> [NovagramVoiceChangerSettingsEntry] {
    let theme = presentationData.theme
    let langCode = NovagramL10n.languageKey(for: presentationData.strings)
    var entries: [NovagramVoiceChangerSettingsEntry] = []
    entries.append(.enable(theme, NovagramVoiceChangerStrings.title(langCode), state.isEnabled))
    entries.append(.enableFooter(theme, NovagramVoiceChangerStrings.switchTip(langCode)))
    // The effect pages only take effect while the voice changer is on, so they show only then.
    if state.isEnabled {
        entries.append(.messages(theme, NovagramVoiceChangerStrings.voiceMessages(langCode), NovagramVoiceChangerStrings.presetName(state.messagesPreset, langCode)))
        entries.append(.messagesFooter(theme, NovagramVoiceChangerStrings.voiceMessagesFooter(langCode)))
        entries.append(.calls(theme, NovagramVoiceChangerStrings.calls(langCode), NovagramVoiceChangerStrings.presetName(state.callsPreset, langCode)))
        entries.append(.callsFooter(theme, NovagramVoiceChangerStrings.callsFooter(langCode)))
    }
    return entries
}

/// `highlightFeature` is `.voiceChangerMessages` or `.voiceChangerCalls` when a per-row link opened the page: that
/// row is traced the same way as on the Novagram settings screen.
public func novagramVoiceChangerSettingsController(context: AccountContext, highlightFeature: NovagramSettingsFeature? = nil) -> ViewController {
    let statePromise = ValuePromise(NovagramVoiceChangerSettingsState.current(), ignoreRepeated: true)
    let refreshState: () -> Void = {
        statePromise.set(NovagramVoiceChangerSettingsState.current())
    }

    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NovagramVoiceChangerSettingsArguments(updateEnabled: { value in
        NovagramVoiceChanger.isEnabled = value
        refreshState()
    }, openMessages: {
        pushControllerImpl?(novagramVoiceChangerController(context: context, forCall: false))
    }, openCalls: {
        pushControllerImpl?(novagramVoiceChangerController(context: context, forCall: true))
    })

    // Picking an effect on a pushed page, or a call changing the live choice, updates the labels here.
    let changedObserver = NotificationCenter.default.addObserver(forName: NovagramVoiceChanger.changedNotification, object: nil, queue: .main) { _ in
        refreshState()
    }

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> deliverOnMainQueue
        |> afterDisposed {
            NotificationCenter.default.removeObserver(changedObserver)
        }
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(NovagramVoiceChangerStrings.title(langCode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramVoiceChangerSettingsEntries(presentationData: presentationData, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    controller.didAppear = { [weak controller] firstTime in
        // The effect pages change the presets while this page stays in the stack: refresh on every return.
        refreshState()
        guard firstTime, let controller else {
            return
        }
        // Press and hold a row to copy or share its link, like on the Novagram settings screen.
        NovagramSettingsRowLinkMenu.attach(to: controller, context: context, title: { feature in
            let langCode = NovagramL10n.languageKey(for: context.sharedContext.currentPresentationData.with { $0 }.strings)
            switch feature {
            case .voiceChangerMessages:
                return NovagramVoiceChangerStrings.voiceMessages(langCode)
            case .voiceChangerCalls:
                return NovagramVoiceChangerStrings.calls(langCode)
            default:
                return nil
            }
        })
        if let highlightFeature {
            let accentColor = context.sharedContext.currentPresentationData.with { $0 }.theme.list.itemAccentColor
            NovagramSettingsHighlight.run(controller: controller, feature: highlightFeature, accentColor: accentColor)
        }
    }
    return controller
}
