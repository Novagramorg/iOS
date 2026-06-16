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
import AppBundle
import ComponentFlow
import FenixuzLocalization
import FenixuzBrand

private enum FenixSection: Int32 {
    case accounts = 5
    case chat = 0
    case interface = 1
    case messaging = 2
    case stt = 3
    case protection = 4
    case appearance = 6
    case chatLock = 7
}

private func textStyleDisplayName(_ rawValue: String, l10n: FenixuzL10n) -> String {
    return l10n.textStyle_displayName(rawValue)
}

private func textStyleExampleDescription(_ rawValue: String, l10n: FenixuzL10n) -> String {
    return l10n.textStyle_example(rawValue)
}

private enum FenixEntry: ItemListNodeEntry {
    // — Chat Section —
    case chatHeader(String)
    case calls(PresentationTheme, String)
    case deletedMessages(PresentationTheme, String, String, Bool)
    case showViewFirstMessage(PresentationTheme, String, String, Bool)
    case showGhostMode(PresentationTheme, String, String, Bool)
    case longPressCameraSelection(PresentationTheme, String, String, Bool)
    case editedHistoryEnabled(PresentationTheme, String, String, Bool)
    case chatFooter(PresentationTheme, String)

    // — Interface Section —
    case interfaceHeader(String)
    case hideFolders(PresentationTheme, String, String, Bool)
    case showStories(PresentationTheme, String, String, Bool)
    case showMutualContactSymbol(PresentationTheme, String, String, Bool)
    case interfaceFooter(PresentationTheme, String)

    // — Messaging Section —
    case messagingHeader(String)
    case textStyle(PresentationTheme, String, String)
    case autoText(PresentationTheme, String, String)
    case autoTranslate(PresentationTheme, String, String)
    case translateToggle(PresentationTheme, String, String, Bool)
    case translateMessages(PresentationTheme, String)
    case messagingFooter(PresentationTheme, String)

    // — STT Section —
    case sttHeader(String)
    case sttEnabled(PresentationTheme, String, String, Bool)
    case sttLanguage(PresentationTheme, String, String)
    // isNew: true while this feature's introducedBuild is newer than the seen-build pointer
    case voiceTranslate(PresentationTheme, String, String, Bool, Bool)

    // — Protection Section —
    case protectionHeader(String)
    case blockForeignUsers(PresentationTheme, String, String, Bool)
    case blockApkFiles(PresentationTheme, String, String, Bool)
    case protectionFooter(PresentationTheme, String)

    // — Appearance Section (Feature #23) —
    // isNew: true while this feature's introducedBuild is newer than the seen-build pointer
    case appearanceHeader(String)
    case whiteThemeAccent(PresentationTheme, String, String, Bool, Bool)
    case appearanceFooter(PresentationTheme, String)

    // — Chat Lock Section (Feature #46) —
    // isNew: true while this feature's introducedBuild is newer than the seen-build pointer
    case chatLockHeader(String, Bool)
    case chatLockInfo(PresentationTheme, String)
    case chatLockFooter(PresentationTheme, String)

    // — Accounts (Fenixuz multi-account) —
    case accountsHeader(String)
    case accountsManager(PresentationTheme, String)
    // — About FenixPro —
    case aboutRow(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .chatHeader, .calls, .deletedMessages, .showViewFirstMessage, .showGhostMode, .longPressCameraSelection, .editedHistoryEnabled, .chatFooter:
            return FenixSection.chat.rawValue
        case .interfaceHeader, .hideFolders, .showStories, .showMutualContactSymbol, .interfaceFooter:
            return FenixSection.interface.rawValue
        case .messagingHeader, .textStyle, .autoText, .autoTranslate, .translateToggle, .translateMessages, .messagingFooter:
            return FenixSection.messaging.rawValue
        case .sttHeader, .sttEnabled, .sttLanguage, .voiceTranslate:
            return FenixSection.stt.rawValue
        case .protectionHeader, .blockForeignUsers, .blockApkFiles, .protectionFooter:
            return FenixSection.protection.rawValue
        case .appearanceHeader, .whiteThemeAccent, .appearanceFooter:
            return FenixSection.appearance.rawValue
        case .chatLockHeader, .chatLockInfo, .chatLockFooter:
            return FenixSection.chatLock.rawValue
        case .accountsHeader, .accountsManager, .aboutRow:
            return FenixSection.accounts.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        // Chat
        case .chatHeader:                return 0
        case .calls:                     return 1
        case .deletedMessages:           return 2
        case .showViewFirstMessage:      return 3
        case .showGhostMode:             return 4
        case .longPressCameraSelection:  return 5
        case .editedHistoryEnabled:      return 7
        case .chatFooter:                return 6
        // Interface
        case .interfaceHeader:           return 10
        case .hideFolders:               return 11
        case .showStories:               return 12
        case .showMutualContactSymbol:   return 13
        case .interfaceFooter:           return 15
        // Messaging
        case .messagingHeader:           return 20
        case .textStyle:                 return 21
        case .autoText:                  return 22
        case .autoTranslate:             return 23
        case .translateToggle:           return 24
        case .translateMessages:         return 25
        case .messagingFooter:           return 26
        // STT
        case .sttHeader:                 return 30
        case .sttEnabled:                return 31
        case .sttLanguage:               return 32
        case .voiceTranslate:            return 33
        // Protection
        case .protectionHeader:          return 40
        case .blockForeignUsers:         return 41
        case .blockApkFiles:             return 42
        case .protectionFooter:          return 43
        // Appearance (Feature #23)
        case .appearanceHeader:          return 50
        case .whiteThemeAccent:          return 51
        case .appearanceFooter:          return 52
        // Chat Lock (Feature #46) — informational section
        case .chatLockHeader:            return 60
        case .chatLockInfo:              return 61
        case .chatLockFooter:            return 62
        // Accounts (rendered at the top of the list)
        case .accountsHeader:            return -2
        case .accountsManager:           return -1
        // About FenixPro row — at the very top, above Accounts
        case .aboutRow:                  return -3
        }
    }

    var sortId: Int {
        return Int(self.stableId)
    }

    static func == (lhs: FenixEntry, rhs: FenixEntry) -> Bool {
        switch lhs {
        case let .chatHeader(lhsText):
            if case let .chatHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .calls(lhsTheme, lhsTitle):
            if case let .calls(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .deletedMessages(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .deletedMessages(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .showViewFirstMessage(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .showViewFirstMessage(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .showGhostMode(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .showGhostMode(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .longPressCameraSelection(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .longPressCameraSelection(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .editedHistoryEnabled(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .editedHistoryEnabled(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .chatFooter(lhsTheme, lhsText):
            if case let .chatFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .interfaceHeader(lhsText):
            if case let .interfaceHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .hideFolders(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .hideFolders(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .showStories(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .showStories(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .showMutualContactSymbol(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .showMutualContactSymbol(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .interfaceFooter(lhsTheme, lhsText):
            if case let .interfaceFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .messagingHeader(lhsText):
            if case let .messagingHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .textStyle(lhsTheme, lhsTitle, lhsLabel):
            if case let .textStyle(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .autoText(lhsTheme, lhsTitle, lhsLabel):
            if case let .autoText(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .autoTranslate(lhsTheme, lhsTitle, lhsLabel):
            if case let .autoTranslate(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .translateToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .translateToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .translateMessages(lhsTheme, lhsTitle):
            if case let .translateMessages(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .messagingFooter(lhsTheme, lhsText):
            if case let .messagingFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .sttHeader(lhsText):
            if case let .sttHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .sttEnabled(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .sttEnabled(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .sttLanguage(lhsTheme, lhsTitle, lhsLabel):
            if case let .sttLanguage(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .voiceTranslate(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .voiceTranslate(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }

        case let .protectionHeader(lhsText):
            if case let .protectionHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .blockForeignUsers(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .blockForeignUsers(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .blockApkFiles(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .blockApkFiles(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .protectionFooter(lhsTheme, lhsText):
            if case let .protectionFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .appearanceHeader(lhsText):
            if case let .appearanceHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .whiteThemeAccent(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .whiteThemeAccent(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .appearanceFooter(lhsTheme, lhsText):
            if case let .appearanceFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .chatLockHeader(lhsText, lhsIsNew):
            if case let .chatLockHeader(rhsText, rhsIsNew) = rhs, lhsText == rhsText, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .chatLockInfo(lhsTheme, lhsText):
            if case let .chatLockInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .chatLockFooter(lhsTheme, lhsText):
            if case let .chatLockFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .accountsHeader(lhsText):
            if case let .accountsHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .accountsManager(lhsTheme, lhsTitle):
            if case let .accountsManager(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .aboutRow(lhsTheme, lhsTitle):
            if case let .aboutRow(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        }
    }

    static func < (lhs: FenixEntry, rhs: FenixEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FenixSettingsArguments
        switch self {
        // ─── ACCOUNTLAR ───
        case let .accountsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .accountsManager(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "person.2.circle.fill", color: .blue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAccounts()
            })
        case let .aboutRow(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "info.circle.fill", color: .blue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAbout()
            })

        // ─── INTERFEYS ───
        case let .interfaceHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .hideFolders(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "folder.badge.minus", color: .lightBlue), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateHideFolders(val)
            })
        case let .showStories(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "circle.dashed", color: .violet), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowStories(val)
            })
        case let .showMutualContactSymbol(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "person.2.fill", color: .blue), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowMutualContactSymbol(val)
            })
        case let .interfaceFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── CHAT ───
        case let .chatHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .calls(_, title):
            // Hidden — Calls is navigation, not a setting. Kept for backward compat.
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "phone.fill", color: .green), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openCalls()
            })
        case let .deletedMessages(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "trash.slash.fill", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowDeletedMessages(val)
            })
        case let .showViewFirstMessage(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "arrow.up.to.line", color: .blue), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowViewFirstMessage(val)
            })
        case let .showGhostMode(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "eye.slash.fill", color: .gray), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowGhostMode(val)
            })
        case let .longPressCameraSelection(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "camera.rotate.fill", color: .orange), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateLongPressCameraSelection(val)
            })
        case let .editedHistoryEnabled(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "clock.arrow.circlepath", color: .teal), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateEditedHistoryEnabled(val)
            })
        case let .chatFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── XABARLAR ───
        case let .messagingHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .textStyle(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "textformat", color: .purple), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openTextStyleSettings()
            })
        case let .autoText(theme, title, label):
            let l10n = FenixuzL10n(presentationData.strings)
            let labelStyle: ItemListDisclosureLabelStyle = (label == l10n.settings_state_enabled) ? .badge(theme.list.itemAccentColor) : .text
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "text.append", color: .teal), title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoTextSettings()
            })
        case let .autoTranslate(theme, title, label):
            let l10n = FenixuzL10n(presentationData.strings)
            let labelStyle: ItemListDisclosureLabelStyle = (label == l10n.settings_state_enabled) ? .badge(theme.list.itemAccentColor) : .text
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "globe", color: .pink), title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoTranslateSettings()
            })
        case let .translateToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "character.bubble.fill", color: .pink), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateTranslateMessages(val)
            })
        case let .translateMessages(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "character.book.closed.fill", color: .lightBlue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openTranslationSettings()
            })
        case let .messagingFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── OVOZ → MATN ───
        case let .sttHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .sttEnabled(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "mic.fill", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateSttEnabled(val)
            })
        case let .sttLanguage(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "globe", color: .blue), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openSttLanguageSettings()
            })
        case let .voiceTranslate(_, title, text, value, isNew):
            // "character.bubble.fill" is iOS 13+ safe; "translate" is iOS 14+ only.
            // isNew: always true for now — flip to false in the call site when no longer new.
            let langCode = presentationData.strings.primaryComponent.languageCode
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(FenixNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: fenixuzSettingsIcon(systemName: "character.bubble.fill", color: .teal),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateVoiceTranslate(val)
                }
            )

        // ─── HIMOYA ───
        case let .protectionHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .blockForeignUsers(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "person.crop.circle.badge.xmark", color: .orange), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateBlockForeignUsers(val)
            })
        case let .blockApkFiles(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: fenixuzSettingsIcon(systemName: "doc.fill.badge.ellipsis", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateBlockApkFiles(val)
            })
        case let .protectionFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── KO'RINISH (APPEARANCE) ───
        case let .appearanceHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .whiteThemeAccent(_, title, text, value, isNew):
            // isNew: always true for now — flip to false in the call site when no longer new.
            let langCode = presentationData.strings.primaryComponent.languageCode
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(FenixNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: fenixuzSettingsIcon(systemName: "paintpalette.fill", color: .green),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateWhiteThemeAccent(val)
                }
            )
        case let .appearanceFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── CHAT LOCK (Feature #46) ───
        case let .chatLockHeader(text, isNew):
            // ItemListSectionHeaderItem has native badge: + badgeStyle: support — use that
            // instead of a text suffix so the badge is a proper green pill.
            let langCode = presentationData.strings.primaryComponent.languageCode
            let badgeText: String? = isNew ? FenixNewBadgeLabel.headerText(langCode: langCode) : nil
            let badgeStyle: ItemListSectionHeaderItem.BadgeStyle? = isNew
                ? ItemListSectionHeaderItem.BadgeStyle(
                    background: UIColor(red: 0.18, green: 0.74, blue: 0.44, alpha: 1.0),
                    foreground: .white
                )
                : nil
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: text,
                badge: badgeText,
                badgeStyle: badgeStyle,
                sectionId: self.section
            )
        case let .chatLockInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .chatLockFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct FenixSettingsState: Equatable {
    var showDeletedMessages: Bool
    var hideFolders: Bool
    var showStories: Bool
    var showMutualContactSymbol: Bool
    var showGhostMode: Bool
    var showViewFirstMessage: Bool
    var longPressCameraSelection: Bool
    var editedHistoryEnabled: Bool
    var showTranslateMessages: Bool
    var textStyle: String
    var autoTextEnabled: Bool
    var autoTranslateEnabled: Bool
    var sttEnabled: Bool
    var sttLanguage: String
    var blockForeignUsers: Bool
    var blockApkFiles: Bool
    var whiteThemeAccentEnabled: Bool
    var voiceTranslateEnabled: Bool

    init() {
        self.showDeletedMessages = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") ?? false
        self.hideFolders = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "hide_folders") ?? false
        self.showStories = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_stories") as? Bool ?? true
        self.showMutualContactSymbol = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_mutual_contact_symbol") as? Bool ?? true
        self.showGhostMode = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_ghost_mode_button") ?? false
        self.showViewFirstMessage = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_view_first_message") ?? false
        self.longPressCameraSelection = UserDefaults(suiteName: "pro_messager")?.object(forKey: "long_press_camera_selection") as? Bool ?? true
        self.editedHistoryEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "edited_history_enabled") as? Bool ?? true
        self.showTranslateMessages = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_translate_messages") as? Bool ?? true
        self.textStyle = UserDefaults(suiteName: "pro_messager")?.string(forKey: "text_style") ?? "none"
        self.autoTextEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_text_enabled") ?? false
        self.autoTranslateEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_translate_enabled") ?? false
        self.sttEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "stt_enabled") as? Bool ?? true
        self.sttLanguage = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        self.blockForeignUsers = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_foreign_users") ?? false
        self.blockApkFiles = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_apk_files") ?? false
        // Default off — user opts in explicitly (light theme stays stock until they toggle it)
        self.whiteThemeAccentEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "white_theme_accent_enabled") ?? false
        // Default off — voice translate is an opt-in power-user feature
        self.voiceTranslateEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "voice_translate_enabled") ?? false
    }

    static func == (lhs: FenixSettingsState, rhs: FenixSettingsState) -> Bool {
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
        if lhs.showViewFirstMessage != rhs.showViewFirstMessage {
            return false
        }
        if lhs.longPressCameraSelection != rhs.longPressCameraSelection {
            return false
        }
        if lhs.editedHistoryEnabled != rhs.editedHistoryEnabled {
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
        if lhs.sttEnabled != rhs.sttEnabled {
            return false
        }
        if lhs.sttLanguage != rhs.sttLanguage {
            return false
        }
        if lhs.whiteThemeAccentEnabled != rhs.whiteThemeAccentEnabled {
            return false
        }
        if lhs.voiceTranslateEnabled != rhs.voiceTranslateEnabled {
            return false
        }
        return true
    }
}

private func sttLanguageDisplayName(_ localeId: String) -> String {
    for (id, name) in sttSupportedLanguages() {
        if id == localeId { return name }
    }
    return localeId
}

private func sttSupportedLanguages() -> [(String, String)] {
    return [
        ("en-US", "🇬🇧 English"),
        ("ru-RU", "🇷🇺 Русский"),
        ("tr-TR", "🇹🇷 Türkçe"),
        ("de-DE", "🇩🇪 Deutsch"),
        ("fr-FR", "🇫🇷 Français"),
        ("es-ES", "🇪🇸 Español"),
        ("it-IT", "🇮🇹 Italiano"),
        ("pt-BR", "🇧🇷 Português"),
        ("ar-SA", "🇸🇦 العربية"),
        ("zh-CN", "🇨🇳 中文"),
        ("ja-JP", "🇯🇵 日本語"),
        ("ko-KR", "🇰🇷 한국어"),
        ("hi-IN", "🇮🇳 हिन्दी"),
        ("nl-NL", "🇳🇱 Nederlands"),
        ("pl-PL", "🇵🇱 Polski"),
        ("sv-SE", "🇸🇪 Svenska"),
        ("da-DK", "🇩🇰 Dansk"),
        ("fi-FI", "🇫🇮 Suomi"),
        ("nb-NO", "🇳🇴 Norsk"),
        ("uk-UA", "🇺🇦 Українська"),
        ("cs-CZ", "🇨🇿 Čeština"),
        ("el-GR", "🇬🇷 Ελληνικά"),
        ("ro-RO", "🇷🇴 Română"),
        ("hu-HU", "🇭🇺 Magyar"),
        ("sk-SK", "🇸🇰 Slovenčina"),
        ("hr-HR", "🇭🇷 Hrvatski"),
        ("ca-ES", "🇪🇸 Català"),
        ("vi-VN", "🇻🇳 Tiếng Việt"),
        ("ms-MY", "🇲🇾 Bahasa Melayu"),
        ("id-ID", "🇮🇩 Bahasa Indonesia"),
        ("th-TH", "🇹🇭 ไทย"),
        ("he-IL", "🇮🇱 עברית"),
        ("en-GB", "🇬🇧 English (UK)"),
        ("en-AU", "🇦🇺 English (AU)"),
        ("fr-CA", "🇨🇦 Français (CA)"),
        ("es-MX", "🇲🇽 Español (MX)"),
        ("zh-TW", "🇹🇼 中文 (繁體)"),
        ("pt-PT", "🇵🇹 Português (PT)")
    ]
}

private func fenixSettingsEntries(presentationData: PresentationData, state: FenixSettingsState) -> [FenixEntry] {
    var entries: [FenixEntry] = []
    let l10n = FenixuzL10n(presentationData.strings)
    // Resolved once at entry-build time; used by local string namespaces throughout.
    let langCode = presentationData.strings.primaryComponent.languageCode

    // ─── ABOUT FENIXPRO ───
    entries.append(.aboutRow(presentationData.theme, l10n.about_rowTitle))

    // ─── ACCOUNTS (Fenixuz multi-account) ───
    entries.append(.accountsHeader(l10n.accounts_sectionHeader))
    entries.append(.accountsManager(presentationData.theme, l10n.accounts_allAccounts))

    // ─── INTERFACE ───
    entries.append(.interfaceHeader(l10n.settings_section_interface))
    entries.append(.hideFolders(presentationData.theme, l10n.settings_interface_hideFolders_title, l10n.settings_interface_hideFolders_subtitle, state.hideFolders))
    entries.append(.showStories(presentationData.theme, l10n.settings_interface_stories_title, l10n.settings_interface_stories_subtitle, state.showStories))
    entries.append(.showMutualContactSymbol(presentationData.theme, l10n.settings_interface_mutualSymbol_title, l10n.settings_interface_mutualSymbol_subtitle, state.showMutualContactSymbol))
    entries.append(.interfaceFooter(presentationData.theme, l10n.settings_interface_footer))

    // ─── CHAT ───
    entries.append(.chatHeader(l10n.settings_section_chat))
    entries.append(.deletedMessages(presentationData.theme, l10n.settings_chat_deletedMessages_title, l10n.settings_chat_deletedMessages_subtitle, state.showDeletedMessages))
    entries.append(.showViewFirstMessage(presentationData.theme, l10n.settings_chat_firstMessage_title, l10n.settings_chat_firstMessage_subtitle, state.showViewFirstMessage))
    entries.append(.showGhostMode(presentationData.theme, l10n.settings_chat_ghost_title, l10n.settings_chat_ghost_subtitle, state.showGhostMode))
    entries.append(.longPressCameraSelection(presentationData.theme, l10n.settings_chat_camera_title, l10n.settings_chat_camera_subtitle, state.longPressCameraSelection))
    entries.append(.editedHistoryEnabled(presentationData.theme, l10n.settings_chat_editedHistory_title, l10n.settings_chat_editedHistory_subtitle, state.editedHistoryEnabled))
    entries.append(.chatFooter(presentationData.theme, l10n.settings_chat_footer))

    // ─── MESSAGING ───
    entries.append(.messagingHeader(l10n.settings_section_messaging))
    entries.append(.textStyle(presentationData.theme, l10n.settings_messaging_textStyle_title, textStyleDisplayName(state.textStyle, l10n: l10n)))

    let autoLabel = state.autoTextEnabled ? l10n.settings_state_enabled : l10n.settings_state_disabled
    entries.append(.autoText(presentationData.theme, l10n.settings_messaging_autoText_title, autoLabel))

    let translateLabel = state.autoTranslateEnabled ? l10n.settings_state_enabled : l10n.settings_state_disabled
    entries.append(.autoTranslate(presentationData.theme, l10n.settings_messaging_autoTranslate_title, translateLabel))

    entries.append(.translateToggle(presentationData.theme, l10n.settings_messaging_translateToggle_title, l10n.settings_messaging_translateToggle_subtitle, state.showTranslateMessages))
    entries.append(.translateMessages(presentationData.theme, l10n.settings_messaging_translateLanguage_title))
    entries.append(.messagingFooter(presentationData.theme, l10n.settings_messaging_footer))

    // ─── VOICE → TEXT ───
    entries.append(.sttHeader(l10n.settings_section_voice))
    entries.append(.sttEnabled(presentationData.theme, l10n.settings_voice_stt_title, l10n.settings_voice_stt_subtitle, state.sttEnabled))

    let sttLangName = sttLanguageDisplayName(state.sttLanguage)
    entries.append(.sttLanguage(presentationData.theme, l10n.settings_voice_sttLang_title, sttLangName))

    // Voice → Translate toggle (Feature #25)
    // Shows when STT is enabled and adds auto-translation of the transcription result.
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    let voiceTranslateTitle    = FenixVoiceTranslateStrings.toggleTitle(langCode: langCode)
    let voiceTranslateSubtitle = FenixVoiceTranslateStrings.toggleSubtitle(langCode: langCode)
    entries.append(.voiceTranslate(presentationData.theme, voiceTranslateTitle, voiceTranslateSubtitle, state.voiceTranslateEnabled, true))

    // ─── PROTECTION ───
    entries.append(.protectionHeader(l10n.settings_section_protection))
    entries.append(.blockForeignUsers(presentationData.theme, l10n.settings_protection_foreign_title, l10n.settings_protection_foreign_subtitle, state.blockForeignUsers))
    entries.append(.blockApkFiles(presentationData.theme, l10n.settings_protection_apk_title, l10n.settings_protection_apk_subtitle, state.blockApkFiles))
    entries.append(.protectionFooter(presentationData.theme, l10n.settings_protection_footer))

    // ─── APPEARANCE (Feature #23) ───
    // Local strings — not in FenixuzL10n to avoid parallel-edit hazard on Localization module.
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    let appearanceTitle = FenixWhiteThemeStrings.sectionTitle(langCode: langCode)
    let accentTitle    = FenixWhiteThemeStrings.toggleTitle(langCode: langCode)
    let accentSubtitle = FenixWhiteThemeStrings.toggleSubtitle(langCode: langCode)
    let accentFooter   = FenixWhiteThemeStrings.footer(langCode: langCode)
    entries.append(.appearanceHeader(appearanceTitle))
    entries.append(.whiteThemeAccent(presentationData.theme, accentTitle, accentSubtitle, state.whiteThemeAccentEnabled, true))
    entries.append(.appearanceFooter(presentationData.theme, accentFooter))

    // ─── CHAT LOCK (Feature #46) ───
    // Informational section — lock is set per-chat via long-press context menu, not via a global toggle here.
    // Local strings to avoid parallel-edit hazard on the shared Localization module.
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    entries.append(.chatLockHeader(FenixChatLockStrings.sectionTitle(langCode: langCode), true))
    entries.append(.chatLockInfo(presentationData.theme, FenixChatLockStrings.infoBody(langCode: langCode)))
    entries.append(.chatLockFooter(presentationData.theme, FenixChatLockStrings.footer(langCode: langCode)))

    // ItemListController entries should arrive in stableId order to avoid an
    // assertion. Section visual order is controlled by stableId numbering.
    return entries.sorted()
}

private final class FenixSettingsArguments {
    let openAccounts: () -> Void
    let openAbout: () -> Void
    let openCalls: () -> Void
    let updateShowDeletedMessages: (Bool) -> Void
    let updateHideFolders: (Bool) -> Void
    let updateShowStories: (Bool) -> Void
    let updateShowMutualContactSymbol: (Bool) -> Void
    let updateShowGhostMode: (Bool) -> Void
    let updateShowViewFirstMessage: (Bool) -> Void
    let updateLongPressCameraSelection: (Bool) -> Void
    let updateEditedHistoryEnabled: (Bool) -> Void
    let updateTranslateMessages: (Bool) -> Void
    let openTranslationSettings: () -> Void
    let openTextStyleSettings: () -> Void
    let openAutoTextSettings: () -> Void
    let openAutoTranslateSettings: () -> Void
    let updateSttEnabled: (Bool) -> Void
    let openSttLanguageSettings: () -> Void
    let updateBlockForeignUsers: (Bool) -> Void
    let updateBlockApkFiles: (Bool) -> Void
    let updateWhiteThemeAccent: (Bool) -> Void
    let updateVoiceTranslate: (Bool) -> Void

    init(openAccounts: @escaping () -> Void, openAbout: @escaping () -> Void, openCalls: @escaping () -> Void, updateShowDeletedMessages: @escaping (Bool) -> Void, updateHideFolders: @escaping (Bool) -> Void, updateShowStories: @escaping (Bool) -> Void, updateShowMutualContactSymbol: @escaping (Bool) -> Void, updateShowGhostMode: @escaping (Bool) -> Void, updateShowViewFirstMessage: @escaping (Bool) -> Void, updateLongPressCameraSelection: @escaping (Bool) -> Void, updateEditedHistoryEnabled: @escaping (Bool) -> Void, updateTranslateMessages: @escaping (Bool) -> Void, openTranslationSettings: @escaping () -> Void, openTextStyleSettings: @escaping () -> Void, openAutoTextSettings: @escaping () -> Void, openAutoTranslateSettings: @escaping () -> Void, updateSttEnabled: @escaping (Bool) -> Void, openSttLanguageSettings: @escaping () -> Void, updateBlockForeignUsers: @escaping (Bool) -> Void, updateBlockApkFiles: @escaping (Bool) -> Void, updateWhiteThemeAccent: @escaping (Bool) -> Void, updateVoiceTranslate: @escaping (Bool) -> Void) {
        self.openAccounts = openAccounts
        self.openAbout = openAbout
        self.openCalls = openCalls
        self.updateShowDeletedMessages = updateShowDeletedMessages
        self.updateHideFolders = updateHideFolders
        self.updateShowStories = updateShowStories
        self.updateShowMutualContactSymbol = updateShowMutualContactSymbol
        self.updateShowGhostMode = updateShowGhostMode
        self.updateShowViewFirstMessage = updateShowViewFirstMessage
        self.updateLongPressCameraSelection = updateLongPressCameraSelection
        self.updateEditedHistoryEnabled = updateEditedHistoryEnabled
        self.updateTranslateMessages = updateTranslateMessages
        self.openTranslationSettings = openTranslationSettings
        self.openTextStyleSettings = openTextStyleSettings
        self.openAutoTextSettings = openAutoTextSettings
        self.openAutoTranslateSettings = openAutoTranslateSettings
        self.updateSttEnabled = updateSttEnabled
        self.openSttLanguageSettings = openSttLanguageSettings
        self.updateBlockForeignUsers = updateBlockForeignUsers
        self.updateBlockApkFiles = updateBlockApkFiles
        self.updateWhiteThemeAccent = updateWhiteThemeAccent
        self.updateVoiceTranslate = updateVoiceTranslate
    }
}

public func fenixSettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(FenixSettingsState(), ignoreRepeated: true)
    let stateValue = Atomic(value: FenixSettingsState())
    let updateState: ((FenixSettingsState) -> FenixSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = FenixSettingsArguments(openAccounts: {
        pushControllerImpl?(fenixAccountsController(context: context))
    }, openAbout: {
        pushControllerImpl?(fenixAboutController(context: context))
    }, openCalls: {
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
        NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
        updateState { state in
            var state = state
            state.hideFolders = value
            return state
        }
    }, updateShowStories: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_stories")
        NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
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
        NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
        updateState { state in
            var state = state
            state.showGhostMode = value
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
    }, updateEditedHistoryEnabled: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "edited_history_enabled")
        updateState { state in
            var state = state
            state.editedHistoryEnabled = value
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
        pushControllerImpl?(fenixTranslationController(context: context))
    }, openTextStyleSettings: {
        pushControllerImpl?(fenixTextStyleController(context: context, onStyleSelected: { newStyle in
            updateState { state in
                var state = state
                state.textStyle = newStyle
                return state
            }
        }))
    }, openAutoTextSettings: {
        pushControllerImpl?(fenixAutoTextController(context: context, onEnabledSelected: { isEnabled in
            updateState { state in
                var state = state
                state.autoTextEnabled = isEnabled
                return state
            }
        }))
    }, openAutoTranslateSettings: {
        pushControllerImpl?(fenixTranslateAutoController(context: context, onEnabledSelected: { isEnabled in
            updateState { state in
                var state = state
                state.autoTranslateEnabled = isEnabled
                return state
            }
        }))
    }, updateSttEnabled: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "stt_enabled")
        updateState { state in
            var state = state
            state.sttEnabled = value
            return state
        }
    }, openSttLanguageSettings: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let languages = sttSupportedLanguages()
        var items: [ActionSheetItem] = []
        for (id, name) in languages {
            items.append(ActionSheetButtonItem(title: name, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                UserDefaults(suiteName: "pro_messager")?.set(id, forKey: "stt_language")
                updateState { state in
                    var state = state
                    state.sttLanguage = id
                    return state
                }
            }))
        }
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
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
    }, updateWhiteThemeAccent: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "white_theme_accent_enabled")
        // Notify observers so any apply-point can react at runtime.
        // The actual theme tinting happens at the apply-point hook described below.
        NotificationCenter.default.post(name: .fenixWhiteThemeAccentChanged, object: nil)
        updateState { state in
            var state = state
            state.whiteThemeAccentEnabled = value
            return state
        }
    }, updateVoiceTranslate: { value in
        // Write to the same key that SpeechToTextManager reads (Feature #25).
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "voice_translate_enabled")
        updateState { state in
            var state = state
            state.voiceTranslateEnabled = value
            return state
        }
    })

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Fenixuz"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: fenixSettingsEntries(presentationData: presentationData, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Notification name (Feature #23)

extension NSNotification.Name {
    // Posted when the user flips the white-theme accent toggle.
    // Apply-point hook: subscribe to this in the place that rebuilds PresentationTheme
    // (e.g. inside the app's theme-override logic) and call
    // FenixWhiteThemeAccent.applyIfNeeded(to:) there.
    public static let fenixWhiteThemeAccentChanged = NSNotification.Name("FenixWhiteThemeAccentChanged")
}

// MARK: - Public read helper (Feature #23)

/// Lets any module read the white-theme-accent preference without importing FenixuzProMessager
/// or referencing UserDefaults key literals directly.
public enum FenixWhiteThemeAccent {
    // UserDefaults key — same suite as all other Fenix settings
    static let udKey   = "white_theme_accent_enabled"
    static let udSuite = "pro_messager"

    /// True when the user has turned on brand accent for the light theme.
    public static var isEnabled: Bool {
        UserDefaults(suiteName: udSuite)?.bool(forKey: udKey) ?? false
    }

    // The actual theme-engine apply-point is upstream and requires
    // PresentationTheme surgery. Call this from the apply-point once it is wired.
    // Returns FenixuzBrandColors.lightThemeAccent when enabled, nil otherwise.
    // TODO apply-point: hook into the app-level theme rebuild triggered by
    //   .fenixWhiteThemeAccentChanged and swap theme.rootController.navigationBar.accentTextColor
    //   (and related tokens) with the returned color when non-nil.
    public static func accentColorIfEnabled() -> UIColor? {
        guard isEnabled else { return nil }
        return FenixuzBrandColors.lightThemeAccent
    }
}

// MARK: - Local string namespace (Feature #23)
// Kept here to avoid the parallel-edit hazard on the shared Localization module.

private enum FenixWhiteThemeStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ko'rinish"
        case "ru": return "Внешний вид"
        default:   return "Appearance"
        }
    }

    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yorqin temada brand rangi"
        case "ru": return "Акцент бренда в светлой теме"
        default:   return "Brand accent in light theme"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yorqin (oq) temada Fenixuz yashil rangini accent sifatida qo'llaydi"
        case "ru": return "Применяет фирменный зелёный Fenixuz в качестве акцента в светлой теме"
        default:   return "Applies Fenixuz emerald as the accent color in the light theme"
        }
    }

    static func footer(langCode: String) -> String {
        switch langCode {
        case "uz": return "Faqat yorqin (oq) temaga ta'sir qiladi. Qayta ishga tushirmasdan kuchga kiradi."
        case "ru": return "Влияет только на светлую тему. Применяется без перезапуска."
        default:   return "Affects the light theme only. Takes effect without restarting."
        }
    }
}

// MARK: - Local string namespace (Feature #46 — Chat Lock)
// Kept local to avoid the parallel-edit hazard on the shared Localization module.
// Lock is set per-chat via long-press → context menu; this section is informational only.

private enum FenixChatLockStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Chat qulfi"
        case "ru": return "Блокировка чата"
        default:   return "Chat Lock"
        }
    }

    // One descriptive paragraph that covers: how to set, PIN vs text, Face/Touch ID.
    static func infoBody(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Istalgan chatni uzoq bosib (long-press) → \"Qulf o'rnatish\" menyusini tanlang. " +
                   "4 xonali PIN-kod yoki ixtiyoriy uzunlikdagi parol o'rnatishingiz mumkin. " +
                   "Qurilmangiz Face ID yoki Touch ID'ni qo'llab-quvvatlasa, biometrik qulfdan ham foydalanishingiz mumkin. " +
                   "Qulflangan chatni ochishda kod yoki biometrik tekshiruv so'raladi."
        case "ru":
            return "Зажмите любой чат (long-press) → выберите «Установить замок». " +
                   "Можно задать 4-значный PIN или пароль произвольной длины. " +
                   "Если устройство поддерживает Face ID или Touch ID, можно включить биометрическую разблокировку. " +
                   "При открытии заблокированного чата потребуется ввод кода или биометрия."
        default:
            return "Long-press any chat → choose \"Set Lock\" from the context menu. " +
                   "You can set a 4-digit PIN or an alphanumeric password of any length. " +
                   "If your device supports Face ID or Touch ID, you can enable biometric unlock. " +
                   "Opening a locked chat will prompt for your code or biometrics."
        }
    }

    static func footer(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Qulf har bir chat uchun alohida o'rnatiladi. Parollar xavfsiz iOS Keychain'da saqlanadi."
        case "ru":
            return "Замок устанавливается отдельно для каждого чата. Пароли хранятся в защищённом iOS Keychain."
        default:
            return "Lock is set per-chat. Credentials are stored in the iOS Keychain."
        }
    }
}

// MARK: - Local string namespace (Feature #25 — Voice Translate)
// Kept local to avoid the parallel-edit hazard on the shared Localization module.
// Target language is reused from the existing auto_translate_lang key — no picker needed here.

private enum FenixVoiceTranslateStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ovozli xabarlarni tarjima qilish"
        case "ru": return "Переводить голосовые сообщения"
        default:   return "Translate voice messages"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Nutqni matnga aylantirgandan so'ng avtomatik tarjima qiladi"
        case "ru": return "Автоматически переводит транскрипцию после распознавания речи"
        default:   return "Automatically translates the transcription after speech recognition"
        }
    }
}

// MARK: - Local string namespace (NEW badge header)
// Short localised text used as the badge label on section headers.
// "NEW" is kept very short so it fits cleanly in the grey header badge pill.

private enum FenixNewBadgeLabel {
    static func headerText(langCode: String) -> String {
        switch langCode {
        case "uz": return "YANGI"
        case "ru": return "НОВОЕ"
        default:   return "NEW"
        }
    }
}
