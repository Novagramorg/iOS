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

private enum ProMessagerSection: Int32 {
    case features
}

private enum ProMessagerEntry: ItemListNodeEntry {
    case deletedMessages(PresentationTheme, String, String, Bool)
    case hideFolders(PresentationTheme, String, String, Bool)
    case showStories(PresentationTheme, String, String, Bool)
    case showMutualContactSymbol(PresentationTheme, String, String, Bool)
    case showGhostMode(PresentationTheme, String, String, Bool)
    case showEnablePremium(PresentationTheme, String, String, Bool)
    case showViewFirstMessage(PresentationTheme, String, String, Bool)
    case longPressCameraSelection(PresentationTheme, String, String, Bool)
    case translateMessages(PresentationTheme, String)
    case translateToggle(PresentationTheme, String, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .deletedMessages, .hideFolders, .showStories, .showMutualContactSymbol, .showGhostMode, .showEnablePremium, .showViewFirstMessage, .longPressCameraSelection, .translateMessages, .translateToggle:
                return ProMessagerSection.features.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .deletedMessages:
                return 0
            case .hideFolders:
                return 1
            case .showStories:
                return 2
            case .showMutualContactSymbol:
                return 3
            case .showGhostMode:
                return 4
            case .showEnablePremium:
                return 5
            case .showViewFirstMessage:
                return 6
            case .longPressCameraSelection:
                return 7
            case .translateToggle:
                return 8
            case .translateMessages:
                return 9
        }
    }
    
    var sortId: Int {
        switch self {
            case .deletedMessages:
                return 0
            case .hideFolders:
                return 1
            case .showStories:
                return 2
            case .showMutualContactSymbol:
                return 3
            case .showGhostMode:
                return 4
            case .showEnablePremium:
                return 5
            case .showViewFirstMessage:
                return 6
            case .longPressCameraSelection:
                return 7
            case .translateToggle:
                return 8
            case .translateMessages:
                return 9
        }
    }
    
    static func ==(lhs: ProMessagerEntry, rhs: ProMessagerEntry) -> Bool {
        switch lhs {
            case let .deletedMessages(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .deletedMessages(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .hideFolders(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .hideFolders(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showStories(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .showStories(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showMutualContactSymbol(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .showMutualContactSymbol(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showGhostMode(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .showGhostMode(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }

            case let .showEnablePremium(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .showEnablePremium(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .showViewFirstMessage(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .showViewFirstMessage(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .longPressCameraSelection(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .longPressCameraSelection(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .translateMessages(lhsTheme, lhsTitle):
                if case let .translateMessages(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .translateToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .translateToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ProMessagerEntry, rhs: ProMessagerEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ProMessagerArguments
        switch self {
            case let .deletedMessages(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateShowDeletedMessages(val)
                })
            case let .hideFolders(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateHideFolders(val)
                })
            case let .showStories(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateShowStories(val)
                })
            case let .showMutualContactSymbol(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateShowMutualContactSymbol(val)
                })
            case let .showGhostMode(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateShowGhostMode(val)
                })
            case let .showEnablePremium(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateShowEnablePremium(val)
                })
            case let .showViewFirstMessage(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateShowViewFirstMessage(val)
                })
            case let .longPressCameraSelection(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateLongPressCameraSelection(val)
                })
            case let .translateMessages(_, title):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openTranslationSettings()
                })
            case let .translateToggle(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateTranslateMessages(val)
                })
        }
    }
}

private struct ProMessagerControllerState: Equatable {
    var showDeletedMessages: Bool
    var hideFolders: Bool
    var showStories: Bool
    var showMutualContactSymbol: Bool
    var showGhostMode: Bool
    var showEnablePremium: Bool
    var showViewFirstMessage: Bool
    var longPressCameraSelection: Bool
    var showTranslateMessages: Bool
    
    init() {
        self.showDeletedMessages = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") ?? false
        self.hideFolders = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "hide_folders") ?? false
        self.showStories = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_stories") as? Bool ?? true
        self.showMutualContactSymbol = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_mutual_contact_symbol") as? Bool ?? true
        self.showGhostMode = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_ghost_mode_button") ?? false
        self.showEnablePremium = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "enable_premium") ?? false
        self.showViewFirstMessage = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_view_first_message") ?? false
        self.longPressCameraSelection = UserDefaults(suiteName: "pro_messager")?.object(forKey: "long_press_camera_selection") as? Bool ?? true
        self.showTranslateMessages = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_translate_messages") as? Bool ?? true
    }
    
    static func ==(lhs: ProMessagerControllerState, rhs: ProMessagerControllerState) -> Bool {
        if lhs.showDeletedMessages != rhs.showDeletedMessages {
            return false
        }
        if lhs.hideFolders != rhs.hideFolders {
            return false
        }
        if lhs.showStories != rhs.showStories {
            return false
        }
        if lhs.showMutualContactSymbol != rhs.showMutualContactSymbol {
            return false
        }
        if lhs.showGhostMode != rhs.showGhostMode {
            return false
        }
        if lhs.showEnablePremium != rhs.showEnablePremium {
            return false
        }
        if lhs.showViewFirstMessage != rhs.showViewFirstMessage {
            return false
        }
        if lhs.longPressCameraSelection != rhs.longPressCameraSelection {
            return false
        }
        if lhs.showTranslateMessages != rhs.showTranslateMessages {
            return false
        }
        return true
    }
}

private func proMessagerControllerEntries(presentationData: PresentationData, state: ProMessagerControllerState) -> [ProMessagerEntry] {
    var entries: [ProMessagerEntry] = []
    
    entries.append(.deletedMessages(presentationData.theme, "O'chirilgan xabarlarni ko'rish", "Agar yoqilgan bo'lsa, chatda o'chirilgan xabarlar 🗑 Removed bilan ko'rsatiladi.", state.showDeletedMessages))
    entries.append(.hideFolders(presentationData.theme, "Jildlarni yashirish", "Tepadagi barcha jildlar boshqalarga ko'rinmasligi uchun ularni vaqtinchalik yashirish", state.hideFolders))
    entries.append(.showStories(presentationData.theme, "Hikoyalarni ko'rsatish", "Chatlar ro'yxatida tepada hikoyalarni ko'rsatish yoki yashirish", state.showStories))
    entries.append(.showMutualContactSymbol(presentationData.theme, "O'zaro kontakt belgisi", "Kontaktlar ro'yxatida o'zaro kontaktlar yonida 🤝 belgisini ko'rsatish", state.showMutualContactSymbol))
    entries.append(.showGhostMode(presentationData.theme, "Ghost rejimi tugmasi", "Chatlar ro'yxati tepasida Ghost rejimini yoqish/o'chirish tugmasini ko'rsatish", state.showGhostMode))
    entries.append(.showEnablePremium(presentationData.theme, "Premium sovg'a", "Barcha Premium imkoniyatlarni bepul ochish (Virtual)", state.showEnablePremium))
    entries.append(.showViewFirstMessage(presentationData.theme, "Birinchi xabarni ko'rish", "Chatda profil rasmiga bosib turganda View First message tugmasini ko'rsatish", state.showViewFirstMessage))
    entries.append(.longPressCameraSelection(presentationData.theme, "Kamerani tanlash", "Video xabar yozish tugmasini bosib turganda kamera tanlash menyusini ko'rsatish", state.longPressCameraSelection))
    entries.append(.translateToggle(presentationData.theme, "Tarjima tugmasini ko'rsatish", "Xabarlarni tarjima qilish uchun context menuda Translate tugmasini ko'rsatish", state.showTranslateMessages))
    entries.append(.translateMessages(presentationData.theme, "Xabarni tarjima qilish tillari"))
    
    return entries
}

private final class ProMessagerArguments {
    let updateShowDeletedMessages: (Bool) -> Void
    let updateHideFolders: (Bool) -> Void
    let updateShowStories: (Bool) -> Void
    let updateShowMutualContactSymbol: (Bool) -> Void
    let updateShowGhostMode: (Bool) -> Void
    let updateShowEnablePremium: (Bool) -> Void
    let updateShowViewFirstMessage: (Bool) -> Void
    let updateLongPressCameraSelection: (Bool) -> Void
    let updateTranslateMessages: (Bool) -> Void
    let openTranslationSettings: () -> Void
    
    init(updateShowDeletedMessages: @escaping (Bool) -> Void, updateHideFolders: @escaping (Bool) -> Void, updateShowStories: @escaping (Bool) -> Void, updateShowMutualContactSymbol: @escaping (Bool) -> Void, updateShowGhostMode: @escaping (Bool) -> Void, updateShowEnablePremium: @escaping (Bool) -> Void, updateShowViewFirstMessage: @escaping (Bool) -> Void, updateLongPressCameraSelection: @escaping (Bool) -> Void, updateTranslateMessages: @escaping (Bool) -> Void, openTranslationSettings: @escaping () -> Void) {
        self.updateShowDeletedMessages = updateShowDeletedMessages
        self.updateHideFolders = updateHideFolders
        self.updateShowStories = updateShowStories
        self.updateShowMutualContactSymbol = updateShowMutualContactSymbol
        self.updateShowGhostMode = updateShowGhostMode
        self.updateShowEnablePremium = updateShowEnablePremium
        self.updateShowViewFirstMessage = updateShowViewFirstMessage
        self.updateLongPressCameraSelection = updateLongPressCameraSelection
        self.updateTranslateMessages = updateTranslateMessages
        self.openTranslationSettings = openTranslationSettings
    }
}

public func proMessagerController(context: AccountContext) -> ViewController {
    if context.isRealPremium {
        UserDefaults(suiteName: "pro_messager")?.set(true, forKey: "enable_premium")
    }
    let statePromise = ValuePromise(ProMessagerControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ProMessagerControllerState())
    let updateState: ((ProMessagerControllerState) -> ProMessagerControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = ProMessagerArguments(updateShowDeletedMessages: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_deleted_messages")
        updateState { state in
            var state = state
            state.showDeletedMessages = value
            return state
        }
    }, updateHideFolders: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "hide_folders")
        NotificationCenter.default.post(name: NSNotification.Name("ProMessagerSettingsChanged"), object: nil)
        updateState { state in
            var state = state
            state.hideFolders = value
            return state
        }
    }, updateShowStories: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_stories")
        NotificationCenter.default.post(name: NSNotification.Name("ProMessagerSettingsChanged"), object: nil)
        updateState { state in
            var state = state
            state.showStories = value
            return state
        }
    }, updateShowMutualContactSymbol: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_mutual_contact_symbol")
        updateState { state in
            var state = state
            state.showMutualContactSymbol = value
            return state
        }
    }, updateShowGhostMode: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_ghost_mode_button")
        NotificationCenter.default.post(name: NSNotification.Name("ProMessagerSettingsChanged"), object: nil)
        updateState { state in
            var state = state
            state.showGhostMode = value
            return state
        }
    }, updateShowEnablePremium: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "enable_premium")
        if value {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let alertController = textAlertController(context: context, title: nil, text: "Bu real Telegram.org premium status emas. Dasturchi tomonidan berilgan Gift", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
            context.sharedContext.mainWindow?.present(alertController, on: .root)
        }
        updateState { state in
            var state = state
            state.showEnablePremium = value
            return state
        }
    }, updateShowViewFirstMessage: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_view_first_message")
        updateState { state in
            var state = state
            state.showViewFirstMessage = value
            return state
        }
    }, updateLongPressCameraSelection: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "long_press_camera_selection")
        updateState { state in
            var state = state
            state.longPressCameraSelection = value
            return state
        }
    }, updateTranslateMessages: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_translate_messages")
        updateState { state in
            var state = state
            state.showTranslateMessages = value
            return state
        }
    }, openTranslationSettings: {
        pushControllerImpl?(proMessagerTranslationController(context: context))
    })
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Pro Messenger"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: proMessagerControllerEntries(presentationData: presentationData, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
