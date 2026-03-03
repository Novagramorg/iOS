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
import CallListUI

private enum ProMessagerSection: Int32 {
    case features
    case protection
}

private func textStyleDisplayName(_ rawValue: String) -> String {
    switch rawValue {
    case "bold":          return "Qalin (Bold)"
    case "italic":        return "Kiyshiq (Italic)"
    case "monospace":     return "Monospace (Kod)"
    case "strikethrough": return "Chizilgan (Strikethrough)"
    case "underline":     return "Tagiga chizilgan (Underline)"
    case "spoiler":       return "Spoiler"
    default:             return "Uslubsiz (Oddiy)"
    }
}

private func textStyleExampleDescription(_ rawValue: String) -> String {
    switch rawValue {
    case "bold":          return "Misol: Salom, bu xabar qalin (Bold) ko'rinishda yuboriladi"
    case "italic":        return "Misol: Salom, bu xabar kiyshiq (Italic) ko'rinishda yuboriladi"
    case "monospace":     return "Misol: Salom, bu xabar monospace (kod) ko'rinishda yuboriladi"
    case "strikethrough": return "Misol: Salom, bu xabar chizilgan ko'rinishda yuboriladi"
    case "underline":     return "Misol: Salom, bu xabar tagiga chizilgan ko'rinishda yuboriladi"
    case "spoiler":       return "Misol: Salom, bu xabar spoiler ko'rinishda yuboriladi (bosib ko'rish kerak)"
    default:             return "Uslub tanlanmagan. Xabarlar oddiy matn sifatida yuboriladi"
    }
}

private enum ProMessagerEntry: ItemListNodeEntry {
    case calls(PresentationTheme, String)
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
    case textStyle(PresentationTheme, String, String)
    case autoText(PresentationTheme, String, String)  // title, status label
    case autoTranslate(PresentationTheme, String, String)
    case protectionHeader(String)
    case blockForeignUsers(PresentationTheme, String, String, Bool)
    case blockApkFiles(PresentationTheme, String, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .calls, .deletedMessages, .hideFolders, .showStories, .showMutualContactSymbol, .showGhostMode, .showEnablePremium, .showViewFirstMessage, .longPressCameraSelection, .translateMessages, .translateToggle, .textStyle, .autoText, .autoTranslate:
                return ProMessagerSection.features.rawValue
            case .protectionHeader, .blockForeignUsers, .blockApkFiles:
                return ProMessagerSection.protection.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .calls:
                return -1
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
            case .textStyle:
                return 10
            case .autoText:
                return 11
            case .autoTranslate:
                return 12
            case .protectionHeader:
                return 13
            case .blockForeignUsers:
                return 14
            case .blockApkFiles:
                return 15
        }
    }
    
    var sortId: Int {
        switch self {
            case .calls:
                return -1
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
            case .textStyle:
                return 10
            case .autoText:
                return 11
            case .autoTranslate:
                return 12
            case .protectionHeader:
                return 13
            case .blockForeignUsers:
                return 14
            case .blockApkFiles:
                return 15
        }
    }
    
    static func ==(lhs: ProMessagerEntry, rhs: ProMessagerEntry) -> Bool {
        switch lhs {
            case let .calls(lhsTheme, lhsTitle):
                if case let .calls(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
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
            case let .textStyle(lhsTheme, lhsTitle, lhsLabel):
                if case let .textStyle(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .autoText(lhsTheme, lhsTitle, lhsLabel):
                if case let .autoText(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .autoTranslate(lhsTheme, lhsTitle, lhsLabel):
                if case let .autoTranslate(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .protectionHeader(lhsText):
                if case let .protectionHeader(rhsText) = rhs, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .blockForeignUsers(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .blockForeignUsers(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .blockApkFiles(lhsTheme, lhsTitle, lhsText, lhsValue):
                if case let .blockApkFiles(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .calls(_, title):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openCalls()
                })
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
            case let .textStyle(_, title, label):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.openTextStyleSettings()
                })
            case let .autoText(theme, title, label):
                let labelStyle: ItemListDisclosureLabelStyle = (label == "Yoqilgan") ? .badge(theme.list.itemAccentColor) : .text
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutoTextSettings()
                })
            case let .autoTranslate(theme, title, label):
                let labelStyle: ItemListDisclosureLabelStyle = (label == "Yoqilgan") ? .badge(theme.list.itemAccentColor) : .text
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                    arguments.openAutoTranslateSettings()
                })
            case let .protectionHeader(text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .blockForeignUsers(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateBlockForeignUsers(val)
                })
            case let .blockApkFiles(_, title, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                    arguments.updateBlockApkFiles(val)
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
    var textStyle: String
    var autoTextEnabled: Bool
    var autoTranslateEnabled: Bool
    var blockForeignUsers: Bool
    var blockApkFiles: Bool
    
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
        self.textStyle = UserDefaults(suiteName: "pro_messager")?.string(forKey: "text_style") ?? "none"
        self.autoTextEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_text_enabled") ?? false
        self.autoTranslateEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_translate_enabled") ?? false
        self.blockForeignUsers = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_foreign_users") ?? false
        self.blockApkFiles = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_apk_files") ?? false
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
        if lhs.textStyle != rhs.textStyle {
            return false
        }
        if lhs.autoTextEnabled != rhs.autoTextEnabled {
            return false
        }
        if lhs.autoTranslateEnabled != rhs.autoTranslateEnabled {
            return false
        }
        if lhs.blockForeignUsers != rhs.blockForeignUsers {
            return false
        }
        if lhs.blockApkFiles != rhs.blockApkFiles {
            return false
        }
        return true
    }
}

private func proMessagerControllerEntries(presentationData: PresentationData, state: ProMessagerControllerState) -> [ProMessagerEntry] {
    var entries: [ProMessagerEntry] = []
    
    entries.append(.calls(presentationData.theme, "Qo'ng'iroqlar"))
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
    entries.append(.textStyle(presentationData.theme, "Xabar uslubi", textStyleDisplayName(state.textStyle)))
    let autoLabel = state.autoTextEnabled ? "Yoqilgan" : "O'chirilgan"
    entries.append(.autoText(presentationData.theme, "Avtomatik qo'shimcha matn", autoLabel))
    
    let translateLabel = state.autoTranslateEnabled ? "Yoqilgan" : "O'chirilgan"
    entries.append(.autoTranslate(presentationData.theme, "Avtomatik xabar tarjimasi", translateLabel))
    
    entries.append(.protectionHeader("SPAM VA FISHINGDAN HIMOYA"))
    entries.append(.blockForeignUsers(presentationData.theme, "Boshqa davlat raqamlariga cheklov", "Boshqa davlat raqamidan ochilgan profillar bir-biriga xabar yozishini taqiqlash", state.blockForeignUsers))
    entries.append(.blockApkFiles(presentationData.theme, ".apk fayllarni bloklash", "Barcha chatlarda (shaxsiy, guruh, kanal, bot) .apk formatdagi fayllarni yashirish", state.blockApkFiles))
    
    return entries
}

private final class ProMessagerArguments {
    let openCalls: () -> Void
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
    let openTextStyleSettings: () -> Void
    let openAutoTextSettings: () -> Void
    let openAutoTranslateSettings: () -> Void
    let updateBlockForeignUsers: (Bool) -> Void
    let updateBlockApkFiles: (Bool) -> Void
    
    init(openCalls: @escaping () -> Void, updateShowDeletedMessages: @escaping (Bool) -> Void, updateHideFolders: @escaping (Bool) -> Void, updateShowStories: @escaping (Bool) -> Void, updateShowMutualContactSymbol: @escaping (Bool) -> Void, updateShowGhostMode: @escaping (Bool) -> Void, updateShowEnablePremium: @escaping (Bool) -> Void, updateShowViewFirstMessage: @escaping (Bool) -> Void, updateLongPressCameraSelection: @escaping (Bool) -> Void, updateTranslateMessages: @escaping (Bool) -> Void, openTranslationSettings: @escaping () -> Void, openTextStyleSettings: @escaping () -> Void, openAutoTextSettings: @escaping () -> Void, openAutoTranslateSettings: @escaping () -> Void, updateBlockForeignUsers: @escaping (Bool) -> Void, updateBlockApkFiles: @escaping (Bool) -> Void) {
        self.openCalls = openCalls
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
        self.openTextStyleSettings = openTextStyleSettings
        self.openAutoTextSettings = openAutoTextSettings
        self.openAutoTranslateSettings = openAutoTranslateSettings
        self.updateBlockForeignUsers = updateBlockForeignUsers
        self.updateBlockApkFiles = updateBlockApkFiles
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
    
    let arguments = ProMessagerArguments(openCalls: {
        pushControllerImpl?(CallListController(context: context, mode: .navigation))
    }, updateShowDeletedMessages: { value in
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
    }, openTextStyleSettings: {
        pushControllerImpl?(proMessagerTextStyleController(context: context, onStyleSelected: { newStyle in
            updateState { state in
                var state = state
                state.textStyle = newStyle
                return state
            }
        }))
    }, openAutoTextSettings: {
        pushControllerImpl?(proMessagerAutoTextController(context: context, onEnabledSelected: { isEnabled in
            updateState { state in
                var state = state
                state.autoTextEnabled = isEnabled
                return state
            }
        }))
    }, openAutoTranslateSettings: {
        pushControllerImpl?(proMessagerTranslateAutoController(context: context, onEnabledSelected: { isEnabled in
            updateState { state in
                var state = state
                state.autoTranslateEnabled = isEnabled
                return state
            }
        }))
    }, updateBlockForeignUsers: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "block_foreign_users")
        updateState { state in
            var state = state
            state.blockForeignUsers = value
            return state
        }
    }, updateBlockApkFiles: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "block_apk_files")
        updateState { state in
            var state = state
            state.blockApkFiles = value
            return state
        }
    })
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Fenixuz"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: proMessagerControllerEntries(presentationData: presentationData, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
