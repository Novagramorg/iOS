import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI

// MARK: - UserDefaults keys
private let kSuiteName   = "pro_messager"
private let kEnabled     = "auto_text_enabled"
private let kContent     = "auto_text_content"

// MARK: - Section

private enum AutoTextSection: Int32 {
    case info
    case settings
    case input
}

// MARK: - Entry

private enum AutoTextEntry: ItemListNodeEntry {
    case infoText(PresentationTheme, String)
    case enableToggle(PresentationTheme, String, String, Bool)
    case textInputHeader(PresentationTheme, String)
    case textInput(PresentationTheme, String, String)   // theme, placeholder, current value
    case inputHint(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .infoText:                          return AutoTextSection.info.rawValue
        case .enableToggle:                      return AutoTextSection.settings.rawValue
        case .textInputHeader, .textInput, .inputHint: return AutoTextSection.input.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .infoText:        return 0
        case .enableToggle:    return 1
        case .textInputHeader: return 2
        case .textInput:       return 3
        case .inputHint:       return 4
        }
    }

    static func ==(lhs: AutoTextEntry, rhs: AutoTextEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.infoText(lt, la), .infoText(rt, ra)):
            return lt === rt && la == ra
        case let (.enableToggle(lt, lti, ltx, lv), .enableToggle(rt, rti, rtx, rv)):
            return lt === rt && lti == rti && ltx == rtx && lv == rv
        case let (.textInputHeader(lt, la), .textInputHeader(rt, ra)):
            return lt === rt && la == ra
        case let (.textInput(lt, lp, lv), .textInput(rt, rp, rv)):
            return lt === rt && lp == rp && lv == rv
        case let (.inputHint(lt, la), .inputHint(rt, ra)):
            return lt === rt && la == ra
        default:
            return false
        }
    }

    static func <(lhs: AutoTextEntry, rhs: AutoTextEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! AutoTextArguments
        switch self {
        case let .infoText(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, style: .blocks)

        case let .enableToggle(_, title, desc, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: desc, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.updateEnabled(val)
            })

        case let .textInputHeader(_, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)

        case let .textInput(_, placeholder, value):
            return ItemListMultilineInputItem(
                presentationData: presentationData,
                text: value,
                placeholder: placeholder,
                maxLength: nil,
                sectionId: self.section,
                style: .blocks,
                capitalization: false,
                autocorrection: false,
                textUpdated: { newText in
                    args.updateContent(newText)
                },
                action: {}
            )

        case let .inputHint(_, hint):
            return ItemListTextItem(presentationData: presentationData, text: .plain(hint), sectionId: self.section, style: .blocks)
        }
    }
}

// MARK: - State

private struct AutoTextState: Equatable {
    var isEnabled: Bool
    var content: String

    init() {
        let ud = UserDefaults(suiteName: kSuiteName)
        self.isEnabled = ud?.bool(forKey: kEnabled) ?? false
        self.content   = ud?.string(forKey: kContent) ?? ""
    }
}

// MARK: - Arguments

private final class AutoTextArguments {
    let updateEnabled: (Bool) -> Void
    let updateContent: (String) -> Void

    init(updateEnabled: @escaping (Bool) -> Void,
         updateContent: @escaping (String) -> Void) {
        self.updateEnabled = updateEnabled
        self.updateContent = updateContent
    }
}

// MARK: - Entries builder

private func autoTextEntries(presentationData: PresentationData, state: AutoTextState) -> [AutoTextEntry] {
    var entries: [AutoTextEntry] = []

    entries.append(.infoText(presentationData.theme,
        "Bu funksiya yoqilganda, siz yozgan xabarning oxiriga avtomatik ravishda qo'shimcha matn qo'shiladi.\n\nMasalan: Siz \"Salom\" deb yozsangiz va qo'shimcha matn \"(Pro)\" bo'lsa, xabar \"Salom (Pro)\" sifatida yuboriladi."))

    entries.append(.enableToggle(presentationData.theme,
        "Avtomatik qo'shimcha",
        "Har bir xabar yuborishda qo'shimcha matn qo'shish",
        state.isEnabled))

    entries.append(.textInputHeader(presentationData.theme, "QO'SHIMCHA MATN"))

    entries.append(.textInput(presentationData.theme,
        "Qo'simcha matnni kiriting...",
        state.content))

    entries.append(.inputHint(presentationData.theme,
        "Xabar yuborilganda shu matn avtomatik qo'shiladi. O'zgarishlar darhol saqlanadi."))

    return entries
}

// MARK: - Controller factory

public func fenixAutoTextController(context: AccountContext, onEnabledSelected: ((Bool) -> Void)? = nil) -> ViewController {
    let statePromise = ValuePromise(AutoTextState(), ignoreRepeated: true)
    let stateValue   = Atomic(value: AutoTextState())

    let updateState: ((AutoTextState) -> AutoTextState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let ud = UserDefaults(suiteName: kSuiteName)

    let arguments = AutoTextArguments(
        updateEnabled: { val in
            ud?.set(val, forKey: kEnabled)
            updateState { s in var s = s; s.isEnabled = val; return s }
            onEnabledSelected?(val)
        },
        updateContent: { text in
            ud?.set(text, forKey: kContent)
            updateState { s in var s = s; s.content = text; return s }
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Avtomatik qo'shimcha"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: autoTextEntries(presentationData: presentationData, state: state),
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
