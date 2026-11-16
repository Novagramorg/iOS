import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ItemListUI
import OverlayStatusController
import PresentationDataUtils
import TextFormat
import NovagramLocalization
import NovagramUzScriptCore

// "Yangi alifbo" (new alphabet): one page with the two switches (send, show) and the Convert text tool.
// The texts come from the SDK (UzScriptStrings), so the Mac says the same words. The conversion itself runs in
// NovagramUzScript (send step and chat bubbles) and in the tool below.

// MARK: - The page

private final class NovagramNewAlphabetArguments {
    let updateSendNew: (Bool) -> Void
    let updateReadNew: (Bool) -> Void
    let updateChatMenu: (Bool) -> Void
    let openConvert: () -> Void

    init(updateSendNew: @escaping (Bool) -> Void, updateReadNew: @escaping (Bool) -> Void, updateChatMenu: @escaping (Bool) -> Void, openConvert: @escaping () -> Void) {
        self.updateSendNew = updateSendNew
        self.updateReadNew = updateReadNew
        self.updateChatMenu = updateChatMenu
        self.openConvert = openConvert
    }
}

private enum NovagramNewAlphabetSection: Int32 {
    case intro
    case send
    case read
    case chatMenu
    case tool
}

private enum NovagramNewAlphabetEntry: ItemListNodeEntry {
    case intro(PresentationTheme, String)
    case send(PresentationTheme, String, String, Bool)
    case read(PresentationTheme, String, String, Bool)
    // Under the send and show switches: only text messages are converted for now.
    case captionsNote(PresentationTheme, String)
    // "Lotin ↔ Кирилл": the per-chat item in a user's profile menu.
    case chatMenu(PresentationTheme, String, String, Bool)
    case convert(PresentationTheme, String)
    case footer(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .intro:
            return NovagramNewAlphabetSection.intro.rawValue
        case .send:
            return NovagramNewAlphabetSection.send.rawValue
        case .read, .captionsNote:
            return NovagramNewAlphabetSection.read.rawValue
        case .chatMenu:
            return NovagramNewAlphabetSection.chatMenu.rawValue
        case .convert, .footer:
            return NovagramNewAlphabetSection.tool.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .intro:
            return 0
        case .send:
            return 2
        case .read:
            return 4
        case .convert:
            return 6
        case .footer:
            return 7
        case .chatMenu:
            return 8
        case .captionsNote:
            return 9
        }
    }

    static func == (lhs: NovagramNewAlphabetEntry, rhs: NovagramNewAlphabetEntry) -> Bool {
        switch lhs {
        case let .intro(lhsTheme, lhsText):
            if case let .intro(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .send(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .send(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .read(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .read(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .chatMenu(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .chatMenu(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .convert(lhsTheme, lhsTitle):
            if case let .convert(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .footer(lhsTheme, lhsText):
            if case let .footer(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .captionsNote(lhsTheme, lhsText):
            if case let .captionsNote(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        }
    }

    // The list is ordered by this: the captions note (stable id 9) and "Lotin ↔ Кирилл" (8) sit after the reading switch.
    private var sortId: Int {
        switch self {
        case .captionsNote:
            return 4 * 10 + 2
        case .chatMenu:
            return 4 * 10 + 5
        default:
            return Int(self.stableId) * 10
        }
    }

    static func < (lhs: NovagramNewAlphabetEntry, rhs: NovagramNewAlphabetEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramNewAlphabetArguments
        switch self {
        case let .intro(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, style: .blocks)
        case let .send(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSendNew(value)
            })
        case let .read(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateReadNew(value)
            })
        case let .chatMenu(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateChatMenu(value)
            })
        case let .convert(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "character.textbox", color: .blue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openConvert()
            })
        case let .footer(_, text), let .captionsNote(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct NovagramNewAlphabetState: Equatable {
    var sendNew: Bool
    var readNew: Bool
    var chatMenu: Bool

    static func current() -> NovagramNewAlphabetState {
        let settings = UzScriptSettings()
        return NovagramNewAlphabetState(sendNew: settings.sendInNewAlphabet, readNew: settings.showChatsInNewAlphabet, chatMenu: settings.cyrillicLatinEnabled)
    }
}

private func novagramNewAlphabetEntries(presentationData: PresentationData, texts: UzScriptStrings, state: NovagramNewAlphabetState) -> [NovagramNewAlphabetEntry] {
    let theme = presentationData.theme
    var entries: [NovagramNewAlphabetEntry] = []
    entries.append(.intro(theme, "**Ş** sh   **Ç** ch   **Ö** oʻ   **Ğ** gʻ\n\n" + texts.heroText))
    entries.append(.send(theme, texts.sendSwitchTitle, texts.sendSwitchSubtitle, state.sendNew))
    entries.append(.read(theme, texts.showSwitchTitle, texts.showSwitchSubtitle, state.readNew))
    entries.append(.captionsNote(theme, texts.captionsNote))
    entries.append(.chatMenu(theme, texts.chatMenuSwitchTitle, texts.chatMenuSwitchSubtitle, state.chatMenu))
    entries.append(.convert(theme, texts.convertTextRow))
    entries.append(.footer(theme, texts.footer))
    return entries
}

/// The "Yangi alifbo" page, opened from its row in Novagram Settings.
func novagramNewAlphabetController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(NovagramNewAlphabetState.current(), ignoreRepeated: true)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = NovagramNewAlphabetArguments(updateSendNew: { value in
        UzScriptSettings().sendInNewAlphabet = value
        statePromise.set(NovagramNewAlphabetState.current())
    }, updateReadNew: { value in
        UzScriptSettings().showChatsInNewAlphabet = value
        statePromise.set(NovagramNewAlphabetState.current())
    }, updateChatMenu: { value in
        UzScriptSettings().cyrillicLatinEnabled = value
        statePromise.set(NovagramNewAlphabetState.current())
    }, openConvert: {
        pushControllerImpl?(novagramUzScriptConvertController(context: context))
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let texts = UzScriptStrings(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(texts.title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramNewAlphabetEntries(presentationData: presentationData, texts: texts, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

// MARK: - Convert text tool

private final class NovagramUzScriptConvertArguments {
    let updateInput: (String) -> Void
    let selectTarget: (UzScript) -> Void
    let copyResult: () -> Void

    init(updateInput: @escaping (String) -> Void, selectTarget: @escaping (UzScript) -> Void, copyResult: @escaping () -> Void) {
        self.updateInput = updateInput
        self.selectTarget = selectTarget
        self.copyResult = copyResult
    }
}

private enum NovagramUzScriptConvertSection: Int32 {
    case input
    case target
    case result
}

// The three scripts the tool converts to, in the order of the design: New Latin, Old Latin, Cyrillic.
private let novagramUzScriptTargets: [UzScript] = [.latin2027, .latin1995, .cyrillic]

private enum NovagramUzScriptConvertEntry: ItemListNodeEntry {
    case input(PresentationTheme, String, String)
    case detected(PresentationTheme, String)
    case targetHeader(String)
    case target(PresentationTheme, Int32, UzScript, String, Bool)
    case result(PresentationTheme, String)
    case copy(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .input, .detected:
            return NovagramUzScriptConvertSection.input.rawValue
        case .targetHeader, .target:
            return NovagramUzScriptConvertSection.target.rawValue
        case .result, .copy:
            return NovagramUzScriptConvertSection.result.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .input:
            return 1
        case .detected:
            return 2
        case .targetHeader:
            return 3
        case let .target(_, index, _, _, _):
            return 4 + index
        case .result:
            return 11
        case .copy:
            return 12
        }
    }

    static func == (lhs: NovagramUzScriptConvertEntry, rhs: NovagramUzScriptConvertEntry) -> Bool {
        switch lhs {
        case let .input(lhsTheme, lhsPlaceholder, lhsText):
            if case let .input(rhsTheme, rhsPlaceholder, rhsText) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsText == rhsText { return true } else { return false }
        case let .detected(lhsTheme, lhsText):
            if case let .detected(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .targetHeader(lhsText):
            if case let .targetHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .target(lhsTheme, lhsIndex, lhsScript, lhsTitle, lhsChecked):
            if case let .target(rhsTheme, rhsIndex, rhsScript, rhsTitle, rhsChecked) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsScript == rhsScript, lhsTitle == rhsTitle, lhsChecked == rhsChecked { return true } else { return false }
        case let .result(lhsTheme, lhsText):
            if case let .result(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .copy(lhsTheme, lhsTitle):
            if case let .copy(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        }
    }

    static func < (lhs: NovagramUzScriptConvertEntry, rhs: NovagramUzScriptConvertEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramUzScriptConvertArguments
        switch self {
        case let .targetHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .input(_, placeholder, text):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, minimalHeight: 88.0, textUpdated: { value in
                arguments.updateInput(value)
            }, action: {})
        case let .detected(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .target(_, _, script, title, checked):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectTarget(script)
            })
        case let .result(_, text):
            return ItemListMultilineTextItem(presentationData: presentationData, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks, longTapAction: {
                arguments.copyResult()
            })
        case let .copy(_, title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.copyResult()
            })
        }
    }
}

private struct NovagramUzScriptConvertState: Equatable {
    var input: String
    var target: UzScript
}

private func novagramUzScriptConvertEntries(presentationData: PresentationData, texts: UzScriptStrings, state: NovagramUzScriptConvertState, result: String) -> [NovagramUzScriptConvertEntry] {
    let theme = presentationData.theme
    var entries: [NovagramUzScriptConvertEntry] = []
    entries.append(.input(theme, texts.inputPlaceholder, state.input))
    if !state.input.isEmpty {
        entries.append(.detected(theme, texts.detectedLabel + ": " + texts.scriptName(UzScriptConverter.detect(state.input))))
    }
    entries.append(.targetHeader(texts.targetLabel))
    for (index, script) in novagramUzScriptTargets.enumerated() {
        entries.append(.target(theme, Int32(index), script, texts.scriptName(script), script == state.target))
    }
    if !result.isEmpty {
        entries.append(.result(theme, result))
        entries.append(.copy(theme, texts.copy))
    }
    return entries
}

private func novagramUzScriptConvertResult(_ state: NovagramUzScriptConvertState) -> String {
    if state.input.isEmpty {
        return ""
    }
    return UzScriptConverter.convert(state.input, to: state.target).text
}

/// Convert text: paste any text, the script is detected, pick the target and copy the result.
func novagramUzScriptConvertController(context: AccountContext) -> ViewController {
    let initialState = NovagramUzScriptConvertState(input: "", target: .latin2027)
    let stateValue = Atomic<NovagramUzScriptConvertState>(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((NovagramUzScriptConvertState) -> NovagramUzScriptConvertState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = NovagramUzScriptConvertArguments(updateInput: { value in
        updateState { state in
            var state = state
            state.input = value
            return state
        }
    }, selectTarget: { script in
        updateState { state in
            var state = state
            state.target = script
            return state
        }
    }, copyResult: {
        let result = novagramUzScriptConvertResult(stateValue.with { $0 })
        guard !result.isEmpty else {
            return
        }
        UIPasteboard.general.string = result
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let texts = UzScriptStrings(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
        presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(texts.copied, false)))
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let texts = UzScriptStrings(languageCode: NovagramL10n.languageKey(for: presentationData.strings))
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(texts.convertTextRow), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let entries = novagramUzScriptConvertEntries(presentationData: presentationData, texts: texts, state: state, result: novagramUzScriptConvertResult(state))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
