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

// MARK: - Localized strings

private enum FenixAutoTextStrings {
    static func info(langCode: String) -> String {
        switch langCode {
        case "uz": return "Bu funksiya yoqilganda, siz yozgan xabarning oxiriga avtomatik ravishda qo'shimcha matn qo'shiladi.\n\nMasalan: Siz \"Salom\" deb yozsangiz va qo'shimcha matn \"(Pro)\" bo'lsa, xabar \"Salom (Pro)\" sifatida yuboriladi."
        case "ru": return "Когда эта функция включена, к концу каждого отправляемого сообщения автоматически добавляется дополнительный текст.\n\nНапример: если вы напишете «Привет», а дополнительный текст — «(Pro)», сообщение будет отправлено как «Привет (Pro)»."
        default:   return "When this feature is enabled, extra text is automatically appended to the end of every message you send.\n\nFor example: if you type \"Hello\" and the extra text is \"(Pro)\", the message is sent as \"Hello (Pro)\"."
        }
    }

    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avtomatik qo'shimcha"
        case "ru": return "Автодобавление"
        default:   return "Auto-append"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Har bir xabar yuborishda qo'shimcha matn qo'shish"
        case "ru": return "Добавлять дополнительный текст при отправке каждого сообщения"
        default:   return "Append extra text on every message send"
        }
    }

    static func inputHeader(langCode: String) -> String {
        switch langCode {
        case "uz": return "QO'SHIMCHA MATN"
        case "ru": return "ДОПОЛНИТЕЛЬНЫЙ ТЕКСТ"
        default:   return "EXTRA TEXT"
        }
    }

    static func inputPlaceholder(langCode: String) -> String {
        switch langCode {
        case "uz": return "Qo'shimcha matnni kiriting..."
        case "ru": return "Введите дополнительный текст..."
        default:   return "Enter the extra text..."
        }
    }

    static func inputHint(langCode: String) -> String {
        switch langCode {
        case "uz": return "Xabar yuborilganda shu matn avtomatik qo'shiladi. O'zgarishlar darhol saqlanadi."
        case "ru": return "Этот текст автоматически добавляется при отправке сообщения. Изменения сохраняются сразу."
        default:   return "This text is automatically appended when a message is sent. Changes are saved immediately."
        }
    }
}

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

    static func == (lhs: AutoTextEntry, rhs: AutoTextEntry) -> Bool {
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

    static func < (lhs: AutoTextEntry, rhs: AutoTextEntry) -> Bool {
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
    let langCode = presentationData.strings.primaryComponent.languageCode

    entries.append(.infoText(presentationData.theme, FenixAutoTextStrings.info(langCode: langCode)))

    entries.append(.enableToggle(presentationData.theme,
        FenixAutoTextStrings.toggleTitle(langCode: langCode),
        FenixAutoTextStrings.toggleSubtitle(langCode: langCode),
        state.isEnabled))

    entries.append(.textInputHeader(presentationData.theme, FenixAutoTextStrings.inputHeader(langCode: langCode)))

    entries.append(.textInput(presentationData.theme,
        FenixAutoTextStrings.inputPlaceholder(langCode: langCode),
        state.content))

    entries.append(.inputHint(presentationData.theme, FenixAutoTextStrings.inputHint(langCode: langCode)))

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
            title: .text(FenixAutoTextStrings.toggleTitle(langCode: presentationData.strings.primaryComponent.languageCode)),
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
