import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramUIPreferences
import ItemListUI
import CallListUI
import AppBundle
import ComponentFlow
import NovagramLocalization
import NovagramBrand
import NovagramUnreadReminder
import NovagramChatLock
import NovagramAutoProxy
import NovagramSecretVault
import NovagramStoryUnlock
import NovagramPremiumUnlock
import NovagramCalls
import NovagramCallRecording

private enum NovagramSection: Int32 {
    case accounts = 5
    case chat = 0
    case interface = 1
    case messaging = 2
    case stt = 3
    case protection = 4
    case appearance = 6
    case chatLock = 7
    case reminder = 8
    case features = 9
    // Developer section — hidden, revealed by a 20 s hold on the Settings version line + developer login
    case developer = 10
    case secretVault = 11
    case carPlay = 12
    case calls = 14
}

private func textStyleDisplayName(_ rawValue: String, l10n: NovagramL10n) -> String {
    return l10n.textStyle_displayName(rawValue)
}

private func textStyleExampleDescription(_ rawValue: String, l10n: NovagramL10n) -> String {
    return l10n.textStyle_example(rawValue)
}

private enum NovagramEntry: ItemListNodeEntry {
    // — Chat Section —
    case chatHeader(String)
    case calls(PresentationTheme, String)
    case deletedMessages(PresentationTheme, String, String, Bool)
    case showViewFirstMessage(PresentationTheme, String, String, Bool)
    case showGhostMode(PresentationTheme, String, String, Bool)
    case longPressCameraSelection(PresentationTheme, String, String, Bool)
    case editedHistoryEnabled(PresentationTheme, String, String, Bool)
    // isNew: true while these features are fresh (NEW pill like sendTranslateConfirm)
    case roundVideoFromGallery(PresentationTheme, String, String, Bool, Bool)
    case forwardHideNames(PresentationTheme, String, String, Bool, Bool)
    case unlimitedPins(PresentationTheme, String, String, Bool, Bool)
    case callsHeader(String)
    case callDataSaving(PresentationTheme, String, String, Bool)
    case callRecording(PresentationTheme, String, String, Bool)
    case callRecordingAuto(PresentationTheme, String, String, Bool)
    case callRecordings(PresentationTheme, String, String)
    case callRecordingFooter(PresentationTheme, String)
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
    // isNew: true — Feature #37 Send-Translate 2-tap confirm
    case sendTranslateConfirm(PresentationTheme, String, String, Bool, Bool)
    // Feature #30: Sticker auto-add after text message
    case autoStickerEnabled(PresentationTheme, String, String, Bool)
    // Feature #34: Heart effect auto-attach to sent messages
    case heartEffectEnabled(PresentationTheme, String, String, Bool)
    case messagingFooter(PresentationTheme, String)

    // — STT Section —
    case sttHeader(String)
    case sttEnabled(PresentationTheme, String, String, Bool)
    case sttLanguage(PresentationTheme, String, String)
    // isNew: true while this feature's introducedBuild is newer than the seen-build pointer
    case voiceTranslate(PresentationTheme, String, String, Bool, Bool, Bool)

    // — CarPlay Section — the row opens the CarPlay page; its label is the Siri permission status
    case carPlayHeader(String, Bool)
    case carPlay(PresentationTheme, String, NovagramCarPlayStatus)
    case carPlayFooter(PresentationTheme, String)

    // — Protection Section —
    case protectionHeader(String)
    case blockForeignUsers(PresentationTheme, String, String, Bool)
    case enableNovagramProxy(PresentationTheme, String, String, Bool)
    // Feature #46: Chat Lock master toggle — enables per-chat lock + sets the master pincode
    case chatLockMasterEnabled(PresentationTheme, String, String, Bool, Bool)
    case autoDownloadDisabled(PresentationTheme, String, String, Bool, Bool)
    // Feature #38: yuborishdan oldin tasdiq so'rovi (ovoz, stiker, sovg'a)
    case sendConfirmEnabled(PresentationTheme, String, String, Bool, Bool)
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
    case secretVaultEnabled(PresentationTheme, String, String, Bool, Bool)
    // Biometric (Face ID / Touch ID) unlock toggle — only shown when a vault PIN exists
    // and the device has biometrics enrolled. Params: theme, title, iconName, value.
    case secretVaultBiometric(PresentationTheme, String, String, Bool)
    case secretVaultFooter(PresentationTheme, String)

    // — Unread Message Reminder Section (Xabar eslatmasi) —
    // isNew: true while this feature's introducedBuild is newer than the seen-build pointer
    case reminderHeader(String, Bool)
    case reminderEnabled(PresentationTheme, String, String, Bool)
    case reminderTime(PresentationTheme, String, String)
    case reminderSound(PresentationTheme, String, String)
    case reminderFooter(PresentationTheme, String)

    // — Features Section (#19 add folders, #21 folder style, #32 channel history, #40 settings links, #45 auto-accept) —
    // isNew: true on section header while this section is newly introduced
    case featuresHeader(String, Bool)
    // Feature #19: add 4 recommended folders in one tap
    case addRecommendedFolders(PresentationTheme, String, String, Bool)
    // Switch for the first-launch "Add folders?" prompt (off by default)
    case foldersPrompt(PresentationTheme, String, String, Bool)
    // Feature #47: auto-managed owner/admin folders (👑/🔑)
    case adminFolders(PresentationTheme, String, String, Bool, Bool)
    // Feature #21: folder display style picker (icon/text/auto)
    case folderStyle(PresentationTheme, String, String, Bool)
    // Feature #32: channel history button (scaffold — behavior in later phase)
    case channelHistoryButton(PresentationTheme, String, String, Bool, Bool)
    // Feature #40: settings links (scaffold — behavior in later phase)
    case settingsLinks(PresentationTheme, String, String, Bool, Bool)
    // Feature #45: auto-accept requests (scaffold — behavior in later phase)
    case autoAcceptRequests(PresentationTheme, String, String, Bool, Bool)
    // Feature #40 (part b): share NovagramPro settings link action row — visible only when settingsLinksEnabled == true
    case shareNovagramProLink(PresentationTheme, String)
    // Client-side unlock for two story-viewer actions upstream gates on isPremium with no
    // server enforcement. See submodules/Novagram/StoryUnlock/.
    case storyUnlockEnabled(PresentationTheme, String, String, Bool, Bool)
    // Client-side unlock for the "Translate Entire Chats" switch upstream gates on isPremium with
    // no server enforcement. See submodules/Novagram/PremiumUnlock/.
    case translateChatsUnlock(PresentationTheme, String, String, Bool, Bool)
    case featuresFooter(PresentationTheme, String)

    // — Developer Section (hidden, see NovagramDeveloperSection) —
    case developerHeader(String)
    // "Remove all ads": the value is the inverse of the stored fenix_show_ads flag
    case showAds(PresentationTheme, String, String, Bool)
    // "Don't send ad events" (NovagramDeveloperFlags.isAdEventsOff)
    case adEventsOff(PresentationTheme, String, String, Bool)
    case currencyRatesView(PresentationTheme, String, String, Bool)
    case adsPanel(PresentationTheme, String, String, Bool)
    // The beta gates (NovagramDeveloperFlags): only .callRecording and .callDataSaving.
    case developerBeta(PresentationTheme, NovagramDeveloperRole.Switch, String, Bool)
    case developerFooter(PresentationTheme, String)

    // — Accounts (Novagram multi-account) —
    case accountsHeader(String)
    case accountsManager(PresentationTheme, String)
    // — About NovagramPro —
    case aboutRow(PresentationTheme, String)
    // — Novagram Bots —
    case novagramBots(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .chatHeader, .calls, .deletedMessages, .showViewFirstMessage, .showGhostMode, .longPressCameraSelection, .editedHistoryEnabled, .roundVideoFromGallery, .forwardHideNames, .chatFooter:
            return NovagramSection.chat.rawValue
        case .interfaceHeader, .hideFolders, .showStories, .showMutualContactSymbol, .unlimitedPins, .interfaceFooter:
            return NovagramSection.interface.rawValue
        case .callsHeader, .callDataSaving, .callRecording, .callRecordingAuto, .callRecordings, .callRecordingFooter:
            return NovagramSection.calls.rawValue
        case .messagingHeader, .textStyle, .autoText, .autoTranslate, .translateToggle, .translateMessages, .sendTranslateConfirm, .autoStickerEnabled, .heartEffectEnabled, .messagingFooter:
            return NovagramSection.messaging.rawValue
        case .sttHeader, .sttEnabled, .sttLanguage, .voiceTranslate:
            return NovagramSection.stt.rawValue
        case .carPlayHeader, .carPlay, .carPlayFooter:
            return NovagramSection.carPlay.rawValue
        case .protectionHeader, .blockForeignUsers, .enableNovagramProxy, .chatLockMasterEnabled, .autoDownloadDisabled, .sendConfirmEnabled, .protectionFooter:
            return NovagramSection.protection.rawValue
        case .appearanceHeader, .whiteThemeAccent, .appearanceFooter:
            return NovagramSection.appearance.rawValue
        case .chatLockHeader, .chatLockInfo, .chatLockFooter:
            return NovagramSection.chatLock.rawValue
        case .secretVaultEnabled, .secretVaultBiometric, .secretVaultFooter:
            return NovagramSection.secretVault.rawValue
        case .reminderHeader, .reminderEnabled, .reminderTime, .reminderSound, .reminderFooter:
            return NovagramSection.reminder.rawValue
        case .featuresHeader, .addRecommendedFolders, .foldersPrompt, .adminFolders, .folderStyle, .channelHistoryButton, .settingsLinks, .autoAcceptRequests, .shareNovagramProLink, .storyUnlockEnabled, .translateChatsUnlock, .featuresFooter:
            return NovagramSection.features.rawValue
        case .developerHeader, .showAds, .adEventsOff, .currencyRatesView, .adsPanel, .developerBeta, .developerFooter:
            return NovagramSection.developer.rawValue
        case .accountsHeader, .accountsManager, .aboutRow, .novagramBots:
            return NovagramSection.accounts.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        // Chat
        case .chatHeader:                return 0
        case .calls:                     return 1
        case .deletedMessages:           return 2
        case .showViewFirstMessage:      return 4
        case .showGhostMode:             return 5
        case .longPressCameraSelection:  return 6
        case .editedHistoryEnabled:      return 3
        case .roundVideoFromGallery:     return 7
        case .forwardHideNames:          return 8
        case .chatFooter:                return 9
        // Interface
        case .interfaceHeader:           return 10
        case .hideFolders:               return 11
        case .showStories:               return 12
        case .showMutualContactSymbol:   return 13
        case .unlimitedPins:             return 14
        case .interfaceFooter:           return 15
        // Calls (53–59; a future "Call recording" switch goes here too)
        case .callsHeader:               return 53
        case .callDataSaving:            return 54
        case .callRecording:             return 55
        case .callRecordingAuto:         return 56
        case .callRecordings:            return 57
        case .callRecordingFooter:       return 58
        // Messaging
        case .messagingHeader:           return 20
        case .textStyle:                 return 21
        case .autoText:                  return 22
        case .autoTranslate:             return 23
        case .translateToggle:           return 24
        case .translateMessages:         return 25
        case .sendTranslateConfirm:      return 26
        case .autoStickerEnabled:        return 27
        case .heartEffectEnabled:        return 28
        case .messagingFooter:           return 29
        // STT
        case .sttHeader:                 return 30
        case .sttEnabled:                return 31
        case .sttLanguage:               return 32
        case .voiceTranslate:            return 33
        // CarPlay
        case .carPlayHeader:             return 35
        case .carPlay:                   return 36
        case .carPlayFooter:             return 37
        // Protection
        case .protectionHeader:          return 40
        case .blockForeignUsers:         return 41
        case .chatLockMasterEnabled:     return 43
        case .autoDownloadDisabled:      return 44
        case .sendConfirmEnabled:        return 45
        case .enableNovagramProxy:        return 46
        case .protectionFooter:          return 47
        // Appearance (Feature #23)
        case .appearanceHeader:          return 50
        case .whiteThemeAccent:          return 51
        case .appearanceFooter:          return 52
        // Chat Lock (Feature #46) — informational section
        case .chatLockHeader:            return 60
        case .chatLockInfo:              return 61
        case .chatLockFooter:            return 62
        case .secretVaultEnabled:        return 63
        case .secretVaultBiometric:      return 64
        case .secretVaultFooter:         return 65
        // Unread Message Reminder (Xabar eslatmasi)
        case .reminderHeader:            return 70
        case .reminderEnabled:           return 71
        case .reminderTime:              return 72
        case .reminderSound:             return 73
        case .reminderFooter:            return 74
        // Features (#19, #21, #32, #40, #45, #47)
        case .featuresHeader:            return 80
        case .addRecommendedFolders:     return 81
        case .foldersPrompt:             return 82
        case .adminFolders:              return 83
        case .folderStyle:               return 84
        case .channelHistoryButton:      return 85
        case .settingsLinks:             return 86
        case .autoAcceptRequests:        return 87
        case .shareNovagramProLink:      return 88
        case .storyUnlockEnabled:        return 89
        case .translateChatsUnlock:      return 90
        case .featuresFooter:            return 91
        // Developer section (hidden)
        case .developerHeader:           return 93
        case .showAds:                   return 94
        case .adEventsOff:               return 95
        case .currencyRatesView:         return 96
        case .adsPanel:                  return 97
        case let .developerBeta(_, item, _, _):
            switch item {
            case .callRecording:         return 100
            case .callDataSaving:        return 101
            default:                     return 99
            }
        case .developerFooter:           return 98
        // Accounts (rendered at the top of the list)
        case .accountsHeader:            return -2
        case .accountsManager:           return -1
        // About NovagramPro row — at the very top, above Accounts
        case .aboutRow:                  return -3
        // Novagram Bots row — above About NovagramPro
        case .novagramBots:              return -4
        }
    }

    // The list is ordered by this, not by the array. Calls use the free stable ids 53–59 but sit right
    // after Interface (10–15), so every id is spread by 10 to leave room before Messaging (20).
    var sortId: Int {
        switch self {
        case .callsHeader:
            return 19 * 10 + 1
        case .callDataSaving:
            return 19 * 10 + 2
        case .callRecording:
            return 19 * 10 + 3
        case .callRecordingAuto:
            return 19 * 10 + 4
        case .callRecordings:
            return 19 * 10 + 5
        case .callRecordingFooter:
            return 19 * 10 + 6
        case let .developerBeta(_, item, _, _):
            switch item {
            case .callRecording:
                return 97 * 10 + 2
            case .callDataSaving:
                return 97 * 10 + 3
            default:
                return 97 * 10 + 1
            }
        default:
            return Int(self.stableId) * 10
        }
    }

    static func == (lhs: NovagramEntry, rhs: NovagramEntry) -> Bool {
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
        case let .roundVideoFromGallery(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .roundVideoFromGallery(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .forwardHideNames(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .forwardHideNames(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .unlimitedPins(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .unlimitedPins(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .callsHeader(lhsText):
            if case let .callsHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .callDataSaving(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .callDataSaving(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .callRecording(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .callRecording(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .callRecordingAuto(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .callRecordingAuto(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .callRecordings(lhsTheme, lhsTitle, lhsLabel):
            if case let .callRecordings(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .callRecordingFooter(lhsTheme, lhsText):
            if case let .callRecordingFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
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
        case let .sendTranslateConfirm(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .sendTranslateConfirm(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .autoStickerEnabled(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .autoStickerEnabled(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .heartEffectEnabled(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .heartEffectEnabled(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .messagingFooter(lhsTheme, lhsText):
            if case let .messagingFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .sttHeader(lhsText):
            if case let .sttHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .sttEnabled(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .sttEnabled(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .sttLanguage(lhsTheme, lhsTitle, lhsLabel):
            if case let .sttLanguage(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .voiceTranslate(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew, lhsEnabled):
            if case let .voiceTranslate(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew, rhsEnabled) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew, lhsEnabled == rhsEnabled { return true } else { return false }

        case let .carPlayHeader(lhsText, lhsIsNew):
            if case let .carPlayHeader(rhsText, rhsIsNew) = rhs, lhsText == rhsText, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .carPlay(lhsTheme, lhsTitle, lhsStatus):
            if case let .carPlay(rhsTheme, rhsTitle, rhsStatus) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsStatus == rhsStatus { return true } else { return false }
        case let .carPlayFooter(lhsTheme, lhsText):
            if case let .carPlayFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .protectionHeader(lhsText):
            if case let .protectionHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .blockForeignUsers(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .blockForeignUsers(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .enableNovagramProxy(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .enableNovagramProxy(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .chatLockMasterEnabled(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .chatLockMasterEnabled(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .autoDownloadDisabled(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .autoDownloadDisabled(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .sendConfirmEnabled(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .sendConfirmEnabled(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
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
        case let .secretVaultEnabled(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .secretVaultEnabled(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .secretVaultBiometric(lhsTheme, lhsTitle, lhsIcon, lhsValue):
            if case let .secretVaultBiometric(rhsTheme, rhsTitle, rhsIcon, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsIcon == rhsIcon, lhsValue == rhsValue { return true } else { return false }
        case let .secretVaultFooter(lhsTheme, lhsText):
            if case let .secretVaultFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .reminderHeader(lhsText, lhsIsNew):
            if case let .reminderHeader(rhsText, rhsIsNew) = rhs, lhsText == rhsText, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .reminderEnabled(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .reminderEnabled(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .reminderTime(lhsTheme, lhsTitle, lhsLabel):
            if case let .reminderTime(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .reminderSound(lhsTheme, lhsTitle, lhsLabel):
            if case let .reminderSound(rhsTheme, rhsTitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel { return true } else { return false }
        case let .reminderFooter(lhsTheme, lhsText):
            if case let .reminderFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .featuresHeader(lhsText, lhsIsNew):
            if case let .featuresHeader(rhsText, rhsIsNew) = rhs, lhsText == rhsText, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .addRecommendedFolders(lhsTheme, lhsTitle, lhsText, lhsIsNew):
            if case let .addRecommendedFolders(rhsTheme, rhsTitle, rhsText, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .foldersPrompt(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .foldersPrompt(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .adminFolders(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .adminFolders(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .folderStyle(lhsTheme, lhsTitle, lhsLabel, lhsIsNew):
            if case let .folderStyle(rhsTheme, rhsTitle, rhsLabel, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsLabel == rhsLabel, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .channelHistoryButton(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .channelHistoryButton(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .settingsLinks(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .settingsLinks(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .autoAcceptRequests(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .autoAcceptRequests(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .shareNovagramProLink(lhsTheme, lhsTitle):
            if case let .shareNovagramProLink(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .storyUnlockEnabled(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .storyUnlockEnabled(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .translateChatsUnlock(lhsTheme, lhsTitle, lhsText, lhsValue, lhsIsNew):
            if case let .translateChatsUnlock(rhsTheme, rhsTitle, rhsText, rhsValue, rhsIsNew) = rhs,
               lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue, lhsIsNew == rhsIsNew { return true } else { return false }
        case let .featuresFooter(lhsTheme, lhsText):
            if case let .featuresFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .developerHeader(lhsText):
            if case let .developerHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .showAds(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .showAds(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .adEventsOff(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .adEventsOff(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .currencyRatesView(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .currencyRatesView(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .adsPanel(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .adsPanel(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .developerBeta(lhsTheme, lhsItem, lhsTitle, lhsValue):
            if case let .developerBeta(rhsTheme, rhsItem, rhsTitle, rhsValue) = rhs, lhsTheme === rhsTheme, lhsItem == rhsItem, lhsTitle == rhsTitle, lhsValue == rhsValue { return true } else { return false }
        case let .developerFooter(lhsTheme, lhsText):
            if case let .developerFooter(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }

        case let .accountsHeader(lhsText):
            if case let .accountsHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .accountsManager(lhsTheme, lhsTitle):
            if case let .accountsManager(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .aboutRow(lhsTheme, lhsTitle):
            if case let .aboutRow(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        case let .novagramBots(lhsTheme, lhsTitle):
            if case let .novagramBots(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true } else { return false }
        }
    }

    static func < (lhs: NovagramEntry, rhs: NovagramEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }

    // Feature #40 (part c): the row's deep-link identity plus the label the share menu shows.
    // Section headers, footers and info paragraphs have none — they are not linkable.
    // A slug is part of a shared URL forever: never repoint one at a different row.
    var linkInfo: (feature: NovagramSettingsFeature, title: String)? {
        switch self {
        case let .aboutRow(_, title):                       return (.about, title)
        case let .accountsManager(_, title):                return (.accounts, title)
        case let .novagramBots(_, title):                   return (.bots, title)

        case let .hideFolders(_, title, _, _):              return (.hideFolders, title)
        case let .showStories(_, title, _, _):              return (.stories, title)
        case let .showMutualContactSymbol(_, title, _, _):  return (.mutualContacts, title)
        case let .unlimitedPins(_, title, _, _, _):         return (.unlimitedPins, title)
        case let .callDataSaving(_, title, _, _):           return (.callDataSaving, title)
        case let .callRecording(_, title, _, _):            return (.callRecording, title)
        case let .callRecordingAuto(_, title, _, _):        return (.callRecordingAuto, title)
        case let .callRecordings(_, title, _):              return (.callRecordings, title)

        case let .deletedMessages(_, title, _, _):          return (.deletedMessages, title)
        case let .editedHistoryEnabled(_, title, _, _):     return (.editedHistory, title)
        case let .showViewFirstMessage(_, title, _, _):     return (.firstMessage, title)
        case let .showGhostMode(_, title, _, _):            return (.ghostMode, title)
        case let .longPressCameraSelection(_, title, _, _): return (.cameraPicker, title)
        case let .roundVideoFromGallery(_, title, _, _, _): return (.roundVideo, title)
        case let .forwardHideNames(_, title, _, _, _):      return (.forwardHideNames, title)

        case let .textStyle(_, title, _):                   return (.textStyle, title)
        case let .autoText(_, title, _):                    return (.autoText, title)
        case let .autoTranslate(_, title, _):               return (.autoTranslate, title)
        case let .translateToggle(_, title, _, _):          return (.translateButton, title)
        case let .translateMessages(_, title):              return (.translateLanguage, title)
        case let .sendTranslateConfirm(_, title, _, _, _):  return (.translateOnSend, title)
        case let .autoStickerEnabled(_, title, _, _):       return (.autoSticker, title)
        case let .heartEffectEnabled(_, title, _, _):       return (.heartEffect, title)

        case let .sttEnabled(_, title, _, _):               return (.voiceToText, title)
        case let .sttLanguage(_, title, _):                 return (.voiceLanguage, title)
        case let .voiceTranslate(_, title, _, _, _, _):     return (.voiceTranslate, title)

        case let .carPlay(_, title, _):                     return (.carPlay, title)

        case let .blockForeignUsers(_, title, _, _):        return (.blockForeign, title)
        case let .chatLockMasterEnabled(_, title, _, _, _): return (.chatLock, title)
        case let .autoDownloadDisabled(_, title, _, _, _):  return (.autoDownload, title)
        case let .sendConfirmEnabled(_, title, _, _, _):    return (.sendConfirm, title)
        case let .enableNovagramProxy(_, title, _, _):      return (.proxy, title)

        case let .whiteThemeAccent(_, title, _, _, _):      return (.whiteAccent, title)

        case let .secretVaultEnabled(_, title, _, _, _):    return (.hiddenChats, title)
        case let .secretVaultBiometric(_, title, _, _):     return (.hiddenChatsBiometrics, title)

        case let .reminderEnabled(_, title, _, _):          return (.reminder, title)
        case let .reminderTime(_, title, _):                return (.reminderTime, title)
        case let .reminderSound(_, title, _):               return (.reminderSound, title)

        case let .addRecommendedFolders(_, title, _, _):    return (.recommendedFolders, title)
        case let .foldersPrompt(_, title, _, _):            return (.foldersPrompt, title)
        case let .adminFolders(_, title, _, _, _):          return (.adminFolders, title)
        case let .folderStyle(_, title, _, _):              return (.folderStyle, title)
        case let .channelHistoryButton(_, title, _, _, _):  return (.channelHistory, title)
        case let .settingsLinks(_, title, _, _, _):         return (.settingsLinks, title)
        case let .autoAcceptRequests(_, title, _, _, _):    return (.autoAccept, title)
        case let .shareNovagramProLink(_, title):           return (.shareLink, title)
        case let .storyUnlockEnabled(_, title, _, _, _):    return (.storySaving, title)
        case let .translateChatsUnlock(_, title, _, _, _):  return (.translateChatsUnlock, title)

        default:                                            return nil
        }
    }

    var feature: NovagramSettingsFeature? {
        return self.linkInfo?.feature
    }

    var novagramTag: ItemListItemTag? {
        guard let feature = self.feature else {
            return nil
        }
        return NovagramSettingsItemTag(feature: feature)
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramSettingsArguments
        switch self {
        // ─── ACCOUNTLAR ───
        case let .accountsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .accountsManager(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "person.2.circle.fill", color: .blue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAccounts()
            }, tag: self.novagramTag)
        case let .aboutRow(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "info.circle.fill", color: .blue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAbout()
            }, tag: self.novagramTag)
        case let .novagramBots(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "bolt.circle.fill", color: .teal), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openNovagramBots()
            }, tag: self.novagramTag)

        // ─── INTERFEYS ───
        case let .interfaceHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .hideFolders(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "folder.badge.minus", color: .lightBlue), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateHideFolders(val)
            }, tag: self.novagramTag)
        case let .showStories(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "circle.dashed", color: .violet), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowStories(val)
            }, tag: self.novagramTag)
        case let .showMutualContactSymbol(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "person.2.fill", color: .blue), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowMutualContactSymbol(val)
            }, tag: self.novagramTag)
        case let .interfaceFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── CHAT ───
        case let .chatHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .calls(_, title):
            // Hidden — Calls is navigation, not a setting. Kept for backward compat.
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "phone.fill", color: .green), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openCalls()
            })
        case let .deletedMessages(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "trash.slash.fill", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowDeletedMessages(val)
            }, tag: self.novagramTag)
        case let .showViewFirstMessage(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "arrow.up.to.line", color: .blue), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowViewFirstMessage(val)
            }, tag: self.novagramTag)
        case let .showGhostMode(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "eye.slash.fill", color: .gray), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateShowGhostMode(val)
            }, tag: self.novagramTag)
        case let .longPressCameraSelection(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "camera.rotate.fill", color: .orange), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateLongPressCameraSelection(val)
            }, tag: self.novagramTag)
        case let .editedHistoryEnabled(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "clock.arrow.circlepath", color: .teal), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateEditedHistoryEnabled(val)
            }, tag: self.novagramTag)
        case let .roundVideoFromGallery(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "video.circle.fill", color: .blue), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateRoundVideoFromGallery(val)
            }, tag: self.novagramTag)
        case let .forwardHideNames(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "arrowshape.turn.up.right.circle.fill", color: .green), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateForwardHideNames(val)
            }, tag: self.novagramTag)
        case let .unlimitedPins(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "pin.circle.fill", color: .orange), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateUnlimitedPins(val)
            }, tag: self.novagramTag)
        case let .callsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .callDataSaving(_, title, text, value):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = AnyComponent(NovagramNewBadgeComponent(langCode: langCode))
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "antenna.radiowaves.left.and.right", color: .green), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateCallDataSaving(val)
            }, tag: self.novagramTag)
        case let .callRecording(_, title, text, value):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = AnyComponent(NovagramNewBadgeComponent(langCode: langCode))
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "record.circle", color: .red), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateCallRecording(val)
            }, tag: self.novagramTag)
        case let .callRecordingAuto(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "arrow.triangle.2.circlepath", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateCallRecordingAuto(val)
            }, tag: self.novagramTag)
        case let .callRecordings(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "waveform", color: .orange), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openCallRecordings()
            }, tag: self.novagramTag)
        case let .callRecordingFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .chatFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── XABARLAR ───
        case let .messagingHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .textStyle(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "textformat", color: .purple), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openTextStyleSettings()
            }, tag: self.novagramTag)
        case let .autoText(theme, title, label):
            let l10n = NovagramL10n(presentationData.strings)
            let labelStyle: ItemListDisclosureLabelStyle = (label == l10n.settings_state_enabled) ? .badge(theme.list.itemAccentColor) : .text
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "text.append", color: .teal), title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoTextSettings()
            }, tag: self.novagramTag)
        case let .autoTranslate(theme, title, label):
            let l10n = NovagramL10n(presentationData.strings)
            let labelStyle: ItemListDisclosureLabelStyle = (label == l10n.settings_state_enabled) ? .badge(theme.list.itemAccentColor) : .text
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "globe", color: .pink), title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoTranslateSettings()
            }, tag: self.novagramTag)
        case let .translateToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "character.bubble.fill", color: .pink), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateTranslateMessages(val)
            }, tag: self.novagramTag)
        case let .translateMessages(_, title):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "character.book.closed.fill", color: .lightBlue), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openTranslationSettings()
            }, tag: self.novagramTag)
        case let .sendTranslateConfirm(_, title, text, value, isNew):
            // Feature #37: 2-tap send confirm toggle (isNew badge)
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "questionmark.bubble.fill", color: .orange),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateSendTranslateConfirm(val)
                },
                tag: self.novagramTag
            )
        case let .autoStickerEnabled(_, title, text, value):
            // Feature #30: Sticker auto-add — sends the last saved sticker after each text message
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "face.smiling.inverse", color: .orange), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateAutoStickerEnabled(val)
            }, tag: self.novagramTag)
        case let .heartEffectEnabled(_, title, text, value):
            // Feature #34: Heart effect — auto-attaches the ❤️ message effect to sent text messages
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "heart.fill", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateHeartEffectEnabled(val)
            }, tag: self.novagramTag)
        case let .messagingFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── OVOZ → MATN ───
        case let .sttHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .sttEnabled(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "mic.fill", color: .red), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateSttEnabled(val)
            }, tag: self.novagramTag)
        case let .sttLanguage(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "globe", color: .blue), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openSttLanguageSettings()
            }, tag: self.novagramTag)
        case let .voiceTranslate(_, title, text, value, isNew, enabled):
            // "character.bubble.fill" is iOS 13+ safe; "translate" is iOS 14+ only.
            // isNew: always true for now — flip to false in the call site when no longer new.
            // enabled: false when "Ask to translate on send" is on (the two are mutually exclusive).
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "character.bubble.fill", color: .teal),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                enabled: enabled,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateVoiceTranslate(val)
                },
                tag: self.novagramTag
            )

        // ─── CARPLAY ───
        case let .carPlayHeader(text, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badgeText: String? = isNew ? NovagramNewBadgeLabel.headerText(langCode: langCode) : nil
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
        case let .carPlay(theme, title, status):
            let (label, labelStyle) = novagramCarPlayStatusLabel(status, theme: theme, strings: presentationData.strings)
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "car.fill", color: .green), title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, action: {
                arguments.openCarPlay()
            }, tag: self.novagramTag)
        case let .carPlayFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── HIMOYA ───
        case let .protectionHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .blockForeignUsers(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "person.crop.circle.badge.xmark", color: .orange), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateBlockForeignUsers(val)
            }, tag: self.novagramTag)
        case let .enableNovagramProxy(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "lock.shield", color: .green), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateEnableNovagramProxy(val)
            }, tag: self.novagramTag)
        case let .chatLockMasterEnabled(_, title, text, value, isNew):
            // Feature #46: Chat Lock master toggle — on turns the feature on and sets the master pincode
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "lock.shield.fill", color: .blue), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateChatLockMaster(val)
            }, tag: self.novagramTag)
        case let .autoDownloadDisabled(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "arrow.down.circle.fill", color: .orange), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateAutoDownloadDisabled(val)
            }, tag: self.novagramTag)
        case let .sendConfirmEnabled(_, title, text, value, isNew):
            // Feature #38: yuborishdan oldin tasdiq so'rovi (ovoz, stiker, sovg'a)
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "hand.raised.fill", color: .purple),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateSendConfirmEnabled(val)
                },
                tag: self.novagramTag
            )
        case let .protectionFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── KO'RINISH (APPEARANCE) ───
        case let .appearanceHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .whiteThemeAccent(_, title, text, value, isNew):
            // isNew: always true for now — flip to false in the call site when no longer new.
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "paintpalette.fill", color: .green),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateWhiteThemeAccent(val)
                },
                tag: self.novagramTag
            )
        case let .appearanceFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── CHAT LOCK (Feature #46) ───
        case let .chatLockHeader(text, isNew):
            // ItemListSectionHeaderItem has native badge: + badgeStyle: support — use that
            // instead of a text suffix so the badge is a proper green pill.
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badgeText: String? = isNew ? NovagramNewBadgeLabel.headerText(langCode: langCode) : nil
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
        case let .secretVaultEnabled(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "eye.slash.fill", color: .purple), title: title, text: text, titleBadgeComponent: badge, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateSecretVault(val)
            }, tag: self.novagramTag)
        case let .secretVaultBiometric(_, title, iconName, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: iconName, color: .purple), title: title, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateSecretVaultBiometric(val)
            }, tag: self.novagramTag)
        case let .secretVaultFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── UNREAD MESSAGE REMINDER (Xabar eslatmasi) ───
        case let .reminderHeader(text, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badgeText: String? = isNew ? NovagramNewBadgeLabel.headerText(langCode: langCode) : nil
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
        case let .reminderEnabled(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "bell.badge.fill", color: .orange), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { val in
                arguments.updateReminderEnabled(val)
            }, tag: self.novagramTag)
        case let .reminderTime(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "clock.fill", color: .blue), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openReminderTimeSettings()
            }, tag: self.novagramTag)
        case let .reminderSound(_, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "speaker.wave.2.fill", color: .pink), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openReminderSoundSettings()
            }, tag: self.novagramTag)
        case let .reminderFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── FEATURES (#19, #21, #32, #40, #45) ───
        case let .featuresHeader(text, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badgeText: String? = isNew ? NovagramNewBadgeLabel.headerText(langCode: langCode) : nil
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
        case let .addRecommendedFolders(_, title, _, _):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "folder.badge.plus", color: .blue),
                title: title,
                label: "",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.addRecommendedFolders()
                },
                tag: self.novagramTag
            )
        case let .foldersPrompt(_, title, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "folder.badge.questionmark", color: .blue),
                title: title,
                text: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateFoldersPrompt(val)
                },
                tag: self.novagramTag
            )
        case let .adminFolders(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "crown.fill", color: .gold),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateAdminFolders(val)
                },
                tag: self.novagramTag
            )
        case let .folderStyle(_, title, label, _):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "square.grid.2x2.fill", color: .purple),
                title: title,
                label: label,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openFolderStyle()
                },
                tag: self.novagramTag
            )
        case let .channelHistoryButton(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "clock.arrow.circlepath", color: .orange),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateChannelHistory(val)
                },
                tag: self.novagramTag
            )
        case let .settingsLinks(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "link.circle.fill", color: .teal),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateSettingsLinks(val)
                },
                tag: self.novagramTag
            )
        case let .autoAcceptRequests(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "checkmark.circle.fill", color: .green),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateAutoAccept(val)
                },
                tag: self.novagramTag
            )
        case let .shareNovagramProLink(_, title):
            // Feature #40 (part b): action row — tapping copies + shares tg://settings/novagrampro
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "square.and.arrow.up.fill", color: .teal),
                title: title,
                label: "",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.shareNovagramProLink()
                },
                tag: self.novagramTag
            )
        case let .featuresFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        // ─── DEVELOPER (hidden section) ───
        case let .developerHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .showAds(_, title, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "megaphone.fill", color: .orange),
                title: title,
                text: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { removeAllAds in
                    arguments.updateShowAds(!removeAllAds)
                },
                tag: self.novagramTag
            )
        case let .adEventsOff(_, title, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "antenna.radiowaves.left.and.right.slash", color: .red),
                title: title,
                text: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateAdEventsOff(value)
                },
                tag: self.novagramTag
            )
        case let .currencyRatesView(_, title, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "dollarsign.circle.fill", color: .green),
                title: title,
                text: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateCurrencyRatesView(value)
                },
                tag: self.novagramTag
            )
        case let .adsPanel(_, title, text, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "rectangle.stack.badge.person.crop.fill", color: .purple),
                title: title,
                text: text,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateAdsPanel(value)
                },
                tag: self.novagramTag
            )
        case let .developerBeta(_, item, title, value):
            let icon: UIImage?
            switch item {
            case .callRecording:
                icon = novagramSettingsIcon(systemName: "record.circle.fill", color: .red)
            case .callDataSaving:
                icon = novagramSettingsIcon(systemName: "antenna.radiowaves.left.and.right", color: .green)
            default:
                icon = novagramSettingsIcon(systemName: "magnifyingglass", color: .blue)
            }
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: icon,
                title: title,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.updateDeveloperBeta(item, value)
                },
                tag: self.novagramTag
            )
        case let .storyUnlockEnabled(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "arrow.down.circle.fill", color: .lightBlue),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateStoryUnlock(val)
                },
                tag: self.novagramTag
            )
        case let .translateChatsUnlock(_, title, text, value, isNew):
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let badge: AnyComponent<Empty>? = isNew ? AnyComponent(NovagramNewBadgeComponent(langCode: langCode)) : nil
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: novagramSettingsIcon(systemName: "character.bubble.fill", color: .lightBlue),
                title: title,
                text: text,
                titleBadgeComponent: badge,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { val in
                    arguments.updateTranslateChatsUnlock(val)
                },
                tag: self.novagramTag
            )
        case let .developerFooter(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct NovagramSettingsState: Equatable {
    var showDeletedMessages: Bool
    var hideFolders: Bool
    var showStories: Bool
    var showMutualContactSymbol: Bool
    var showGhostMode: Bool
    var showViewFirstMessage: Bool
    var longPressCameraSelection: Bool
    var editedHistoryEnabled: Bool
    var roundVideoFromGallery: Bool
    var forwardHideNames: Bool
    var unlimitedPins: Bool
    var callRecording: Bool
    var callRecordingAuto: Bool
    var callRecordingCount: Int
    var showTranslateMessages: Bool
    var textStyle: String
    var autoTextEnabled: Bool
    var autoTranslateEnabled: Bool
    var sttEnabled: Bool
    var sttLanguage: String
    var blockForeignUsers: Bool
    var enableNovagramProxy: Bool
    // Feature #46: Chat Lock master toggle — mirrors ChatPincodeManager.isMasterEnabled()
    var chatLockMasterEnabled: Bool
    var secretVaultEnabled: Bool
    // Vault biometric unlock opt-in — mirrors ChatPincodeManager.getVaultMetadata().biometricEnabled
    var secretVaultBiometricEnabled: Bool
    var whiteThemeAccentEnabled: Bool
    var voiceTranslateEnabled: Bool
    var autoDownloadDisabled: Bool
    // Feature #37: yuborishdan oldin tarjima tasdiq so'rovi
    var translateConfirmEnabled: Bool
    var translateConfirmTargetLanguage: String
    // Feature #38: yuborishdan oldin umumiy tasdiq so'rovi (ovoz, stiker, sovg'a)
    var sendConfirmEnabled: Bool
    // Feature #30: Sticker auto-add — after each text message, append last saved sticker
    var autoStickerEnabled: Bool
    // Feature #34: Heart effect — auto-attach ❤️ message effect to sent messages
    var heartEffectEnabled: Bool
    // Unread message reminder (Xabar eslatmasi)
    var reminderEnabled: Bool
    var reminderMinutes: Int
    var reminderSound: String
    // Features section (#19 folder style, #32, #40, #45 — scaffold storage)
    var folderStyle: String
    var channelHistoryEnabled: Bool
    var settingsLinksEnabled: Bool
    var autoAcceptEnabled: Bool
    var adminFoldersEnabled: Bool
    // Mirrors NovagramRecommendedFolders.isFirstLaunchPromptEnabled; default false.
    var foldersPromptEnabled: Bool
    // Mirrors NovagramStoryUnlock.isEnabled; default false.
    var storyUnlockEnabled: Bool
    // Mirrors NovagramPremiumUnlock.isTranslateChatsUnlocked; default false.
    var translateChatsUnlock: Bool
    // Developer section (hidden)
    // Default true: sponsored messages shown (standard Telegram behavior)
    var showAds: Bool
    // Mirror NovagramDeveloperFlags; default false.
    var adEventsOff: Bool
    var currencyRatesViewEnabled: Bool
    var adsPanelEnabled: Bool
    // The beta gates (NovagramDeveloperFlags). Off hides the matching Settings rows.
    var devCallRecording: Bool
    var devCallDataSaving: Bool
    // Default false: hidden until the 20 s hold on the Settings version line reveals it
    var developerSectionRevealed: Bool
    // The login that revealed it decides which switches show
    var developerRole: NovagramDeveloperRole

    init() {
        self.showDeletedMessages = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") ?? false
        self.hideFolders = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "hide_folders") ?? false
        self.showStories = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_stories") as? Bool ?? true
        self.showMutualContactSymbol = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_mutual_contact_symbol") as? Bool ?? true
        self.showGhostMode = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_ghost_mode_button") ?? false
        self.showViewFirstMessage = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_view_first_message") ?? false
        self.longPressCameraSelection = UserDefaults(suiteName: "pro_messager")?.object(forKey: "long_press_camera_selection") as? Bool ?? false
        self.editedHistoryEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "edited_history_enabled") as? Bool ?? true
        self.roundVideoFromGallery = UserDefaults(suiteName: "pro_messager")?.object(forKey: "round_video_from_gallery") as? Bool ?? false
        self.forwardHideNames = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "forward_hide_names") ?? false
        self.unlimitedPins = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "unlimited_pins") ?? false
        // The user's own switches as stored; the Developer gates are applied by hiding the rows.
        self.callRecording = NovagramCallRecordingSettings.isUserEnabled
        self.callRecordingAuto = NovagramCallRecordingSettings.isUserAutoEnabled
        self.callRecordingCount = NovagramCallRecordingStorage.list().count
        self.showTranslateMessages = UserDefaults(suiteName: "pro_messager")?.object(forKey: "show_translate_messages") as? Bool ?? false
        self.textStyle = UserDefaults(suiteName: "pro_messager")?.string(forKey: "text_style") ?? "none"
        self.autoTextEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_text_enabled") ?? false
        self.autoTranslateEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_translate_enabled") ?? false
        self.sttEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "stt_enabled") as? Bool ?? false
        self.sttLanguage = UserDefaults(suiteName: "pro_messager")?.string(forKey: "stt_language") ?? "en-US"
        self.blockForeignUsers = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_foreign_users") ?? false
        self.enableNovagramProxy = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "novagram_proxy_enabled") ?? false
        // Feature #46: read live from the keychain-backed manager (its own store, not UserDefaults)
        self.chatLockMasterEnabled = ChatPincodeManager.shared.isMasterEnabled()
        self.secretVaultEnabled = ChatPincodeManager.shared.isVaultEnabled()
        self.secretVaultBiometricEnabled = ChatPincodeManager.shared.getVaultMetadata().biometricEnabled
        // Default off — user opts in explicitly (light theme stays stock until they toggle it)
        self.whiteThemeAccentEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "white_theme_accent_enabled") ?? false
        // Default off — voice translate is an opt-in power-user feature
        self.voiceTranslateEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "voice_translate_enabled") ?? false
        // Default off — when on, all media auto-download is turned off
        self.autoDownloadDisabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_download_disabled") ?? false
        // Default off — user opts in (Feature #37)
        self.translateConfirmEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "translate_confirm_enabled") ?? false
        self.translateConfirmTargetLanguage = NovagramSendTranslate.confirmTargetLanguage()
        // Default off — user opts in (Feature #38)
        self.sendConfirmEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "send_confirm_enabled") ?? false
        // Default off — user opts in (Feature #30)
        self.autoStickerEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "auto_sticker_enabled") ?? false
        // Default off — user opts in (Feature #34)
        self.heartEffectEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "heart_effect_enabled") ?? false
        // Unread message reminder (Xabar eslatmasi) — default off, 5 min, default sound
        self.reminderEnabled = UserDefaults(suiteName: "pro_messager")?.object(forKey: "unread_reminder_enabled") as? Bool ?? false
        self.reminderMinutes = UserDefaults(suiteName: "pro_messager")?.object(forKey: "unread_reminder_minutes") as? Int ?? NovagramUnreadReminderSettings.defaultMinutes
        self.reminderSound = UserDefaults(suiteName: "pro_messager")?.string(forKey: "unread_reminder_sound") ?? NovagramUnreadReminderSettings.defaultSound
        // Features section — folder display style, channel history, settings links, auto-accept (scaffold)
        self.folderStyle = UserDefaults(suiteName: "pro_messager")?.string(forKey: "fenix_folder_display_style") ?? "auto"
        self.channelHistoryEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "fenix_channel_history_button") ?? false
        self.settingsLinksEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "fenix_settings_links") ?? false
        self.autoAcceptEnabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "fenix_autoaccept_global") ?? false
        self.adminFoldersEnabled = NovagramAdminFoldersManager.isEnabled
        self.foldersPromptEnabled = NovagramRecommendedFolders.isFirstLaunchPromptEnabled
        self.storyUnlockEnabled = NovagramStoryUnlock.isEnabled
        self.translateChatsUnlock = NovagramPremiumUnlock.isTranslateChatsUnlocked
        // Developer section — default true (show ads), switches off, section hidden
        self.developerSectionRevealed = NovagramDeveloperSection.isRevealed
        self.developerRole = NovagramDeveloperRole.current
        self.showAds = NovagramShowAdsGate.isEnabled
        self.adEventsOff = NovagramDeveloperFlags.isAdEventsOff
        self.currencyRatesViewEnabled = NovagramDeveloperFlags.isCurrencyRatesViewEnabled
        self.adsPanelEnabled = NovagramDeveloperFlags.isAdsPanelEnabled
        self.devCallRecording = NovagramDeveloperFlags.isCallRecordingEnabled
        self.devCallDataSaving = NovagramDeveloperFlags.isCallDataSavingEnabled
    }

    static func == (lhs: NovagramSettingsState, rhs: NovagramSettingsState) -> Bool {
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
        if lhs.roundVideoFromGallery != rhs.roundVideoFromGallery {
            return false
        }
        if lhs.forwardHideNames != rhs.forwardHideNames {
            return false
        }
        if lhs.unlimitedPins != rhs.unlimitedPins {
            return false
        }
        if lhs.callRecording != rhs.callRecording || lhs.callRecordingAuto != rhs.callRecordingAuto || lhs.callRecordingCount != rhs.callRecordingCount {
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
        if lhs.enableNovagramProxy != rhs.enableNovagramProxy {
            return false
        }
        if lhs.chatLockMasterEnabled != rhs.chatLockMasterEnabled {
            return false
        }
        if lhs.secretVaultEnabled != rhs.secretVaultEnabled {
            return false
        }
        if lhs.secretVaultBiometricEnabled != rhs.secretVaultBiometricEnabled {
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
        if lhs.autoDownloadDisabled != rhs.autoDownloadDisabled {
            return false
        }
        if lhs.translateConfirmEnabled != rhs.translateConfirmEnabled {
            return false
        }
        if lhs.translateConfirmTargetLanguage != rhs.translateConfirmTargetLanguage {
            return false
        }
        if lhs.sendConfirmEnabled != rhs.sendConfirmEnabled {
            return false
        }
        if lhs.autoStickerEnabled != rhs.autoStickerEnabled {
            return false
        }
        if lhs.heartEffectEnabled != rhs.heartEffectEnabled {
            return false
        }
        if lhs.reminderEnabled != rhs.reminderEnabled {
            return false
        }
        if lhs.reminderMinutes != rhs.reminderMinutes {
            return false
        }
        if lhs.reminderSound != rhs.reminderSound {
            return false
        }
        if lhs.folderStyle != rhs.folderStyle {
            return false
        }
        if lhs.channelHistoryEnabled != rhs.channelHistoryEnabled {
            return false
        }
        if lhs.settingsLinksEnabled != rhs.settingsLinksEnabled {
            return false
        }
        if lhs.autoAcceptEnabled != rhs.autoAcceptEnabled {
            return false
        }
        if lhs.adminFoldersEnabled != rhs.adminFoldersEnabled {
            return false
        }
        if lhs.foldersPromptEnabled != rhs.foldersPromptEnabled {
            return false
        }
        if lhs.storyUnlockEnabled != rhs.storyUnlockEnabled {
            return false
        }
        if lhs.translateChatsUnlock != rhs.translateChatsUnlock {
            return false
        }
        if lhs.showAds != rhs.showAds {
            return false
        }
        if lhs.adEventsOff != rhs.adEventsOff {
            return false
        }
        if lhs.currencyRatesViewEnabled != rhs.currencyRatesViewEnabled {
            return false
        }
        if lhs.adsPanelEnabled != rhs.adsPanelEnabled {
            return false
        }
        if lhs.developerSectionRevealed != rhs.developerSectionRevealed {
            return false
        }
        if lhs.developerRole != rhs.developerRole {
            return false
        }
        if lhs.devCallRecording != rhs.devCallRecording || lhs.devCallDataSaving != rhs.devCallDataSaving {
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
        ("uz-UZ", "🇺🇿 O'zbekcha"),
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

private func novagramSettingsEntries(presentationData: PresentationData, state: NovagramSettingsState, carPlayStatus: NovagramCarPlayStatus, callDataSaving: Bool) -> [NovagramEntry] {
    var entries: [NovagramEntry] = []
    let l10n = NovagramL10n(presentationData.strings)
    // Resolved once at entry-build time; used by local string namespaces throughout.
    let langCode = NovagramL10n.languageKey(for: presentationData.strings)

    // ─── ABOUT NOVAGRAMPRO ───
    entries.append(.aboutRow(presentationData.theme, l10n.about_rowTitle))

    // ─── ACCOUNTS (Novagram multi-account) ───
    entries.append(.accountsHeader(l10n.accounts_sectionHeader))
    entries.append(.accountsManager(presentationData.theme, l10n.accounts_allAccounts))

    // ─── INTERFACE ───
    entries.append(.interfaceHeader(l10n.settings_section_interface))
    entries.append(.hideFolders(presentationData.theme, l10n.settings_interface_hideFolders_title, l10n.settings_interface_hideFolders_subtitle, state.hideFolders))
    entries.append(.showStories(presentationData.theme, l10n.settings_interface_stories_title, l10n.settings_interface_stories_subtitle, state.showStories))
    entries.append(.showMutualContactSymbol(presentationData.theme, l10n.settings_interface_mutualSymbol_title, l10n.settings_interface_mutualSymbol_subtitle, state.showMutualContactSymbol))
    entries.append(.unlimitedPins(presentationData.theme, l10n.settings_interface_unlimitedPins_title, l10n.settings_interface_unlimitedPins_subtitle, state.unlimitedPins, true))
    entries.append(.interfaceFooter(presentationData.theme, l10n.settings_interface_footer))

    // ─── CALLS ───
    // Each part sits behind its own Developer switch; with neither on the section, header included, is gone.
    if state.devCallDataSaving || state.devCallRecording {
        entries.append(.callsHeader(l10n.settings_section_calls))
    }
    if state.devCallDataSaving {
        // The switch shows Telegram's live call data saving setting (NovagramCallDataSaving).
        entries.append(.callDataSaving(presentationData.theme, l10n.settings_callDataSaving_title, l10n.settings_callDataSaving_subtitle, callDataSaving))
    }
    if state.devCallRecording {
        // Call recording: auto-record only while recording is on; the list while recording is on or a file exists.
        entries.append(.callRecording(presentationData.theme, l10n.settings_callRecording_title, l10n.settings_callRecording_subtitle, state.callRecording))
        if state.callRecording {
            entries.append(.callRecordingAuto(presentationData.theme, l10n.settings_callRecordingAuto_title, l10n.settings_callRecordingAuto_subtitle, state.callRecordingAuto))
        }
        if state.callRecording || state.callRecordingCount > 0 {
            entries.append(.callRecordings(presentationData.theme, l10n.settings_callRecordings_title, state.callRecordingCount > 0 ? "\(state.callRecordingCount)" : ""))
        }
        entries.append(.callRecordingFooter(presentationData.theme, l10n.settings_callRecording_footer))
    }

    // ─── CHAT ───
    entries.append(.chatHeader(l10n.settings_section_chat))
    entries.append(.deletedMessages(presentationData.theme, l10n.settings_chat_deletedMessages_title, l10n.settings_chat_deletedMessages_subtitle, state.showDeletedMessages))
    entries.append(.editedHistoryEnabled(presentationData.theme, l10n.settings_chat_editedHistory_title, l10n.settings_chat_editedHistory_subtitle, state.editedHistoryEnabled))
    entries.append(.showViewFirstMessage(presentationData.theme, l10n.settings_chat_firstMessage_title, l10n.settings_chat_firstMessage_subtitle, state.showViewFirstMessage))
    entries.append(.showGhostMode(presentationData.theme, l10n.settings_chat_ghost_title, l10n.settings_chat_ghost_subtitle, state.showGhostMode))
    entries.append(.longPressCameraSelection(presentationData.theme, l10n.settings_chat_camera_title, l10n.settings_chat_camera_subtitle, state.longPressCameraSelection))
    entries.append(.roundVideoFromGallery(presentationData.theme, l10n.settings_chat_roundVideoGallery_title, l10n.settings_chat_roundVideoGallery_subtitle, state.roundVideoFromGallery, true))
    entries.append(.forwardHideNames(presentationData.theme, l10n.settings_chat_forwardHideNames_title, l10n.settings_chat_forwardHideNames_subtitle, state.forwardHideNames, true))
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

    // Feature #37: Send-Translate 2-tap confirm toggle
    // isNew: true — set to false here when this feature is no longer new
    let sendConfirmTitle    = NovagramSendTranslateStrings.toggleTitle(langCode: langCode)
    let sendConfirmTarget = NovagramSendTranslate.languageName(code: state.translateConfirmTargetLanguage, appLangCode: langCode)
    let sendConfirmSubtitle = NovagramSendTranslateStrings.toggleSubtitle(langCode: langCode) + "\n" + NovagramSendTranslateStrings.targetLine(sendConfirmTarget, langCode: langCode)
    entries.append(.sendTranslateConfirm(presentationData.theme, sendConfirmTitle, sendConfirmSubtitle, state.translateConfirmEnabled, false))

    // Feature #30: Sticker auto-add toggle
    entries.append(.autoStickerEnabled(presentationData.theme, NovagramAutoStickerStrings.toggleTitle(langCode: langCode), NovagramAutoStickerStrings.toggleSubtitle(langCode: langCode), state.autoStickerEnabled))

    // Feature #34: Heart effect toggle
    entries.append(.heartEffectEnabled(presentationData.theme, NovagramHeartEffectStrings.toggleTitle(langCode: langCode), NovagramHeartEffectStrings.toggleSubtitle(langCode: langCode), state.heartEffectEnabled))

    entries.append(.messagingFooter(presentationData.theme, l10n.settings_messaging_footer))

    // ─── VOICE → TEXT ───
    entries.append(.sttHeader(l10n.settings_section_voice))
    entries.append(.sttEnabled(presentationData.theme, l10n.settings_voice_stt_title, l10n.settings_voice_stt_subtitle, state.sttEnabled))

    let sttLangName = sttLanguageDisplayName(state.sttLanguage)
    entries.append(.sttLanguage(presentationData.theme, l10n.settings_voice_sttLang_title, sttLangName))

    // Voice → Translate toggle (Feature #25)
    // Shows when STT is enabled and adds auto-translation of the transcription result.
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    let voiceTranslateTitle    = NovagramVoiceTranslateStrings.toggleTitle(langCode: langCode)
    let voiceTranslateSubtitle = NovagramVoiceTranslateStrings.toggleSubtitle(langCode: langCode)
    entries.append(.voiceTranslate(presentationData.theme, voiceTranslateTitle, voiceTranslateSubtitle, state.voiceTranslateEnabled, false, !state.translateConfirmEnabled))

    // ─── CARPLAY ───
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    // CarPlay only ever connects to an iPhone, so iPad does not get the row.
    if UIDevice.current.userInterfaceIdiom == .phone {
        entries.append(.carPlayHeader(NovagramCarPlayStrings.title(langCode: langCode), true))
        entries.append(.carPlay(presentationData.theme, NovagramCarPlayStrings.title(langCode: langCode), carPlayStatus))
        entries.append(.carPlayFooter(presentationData.theme, NovagramCarPlayStrings.mainFooter(langCode: langCode)))
    }

    // ─── PROTECTION ───
    entries.append(.protectionHeader(l10n.settings_section_protection))
    entries.append(.blockForeignUsers(presentationData.theme, l10n.settings_protection_foreign_title, l10n.settings_protection_foreign_subtitle, state.blockForeignUsers))
    // Feature #46: Chat Lock master toggle — value tracks the keychain-backed master pincode
    entries.append(.chatLockMasterEnabled(presentationData.theme, NovagramSettingsChatLockStrings.toggleTitle(langCode: langCode), NovagramSettingsChatLockStrings.toggleSubtitle(langCode: langCode), state.chatLockMasterEnabled, true))
    entries.append(.autoDownloadDisabled(presentationData.theme, NovagramAutoDownloadStrings.title(langCode: langCode), NovagramAutoDownloadStrings.subtitle(langCode: langCode), state.autoDownloadDisabled, false))
    // Feature #38: yuborishdan oldin tasdiq so'rovi toggle
    entries.append(.sendConfirmEnabled(presentationData.theme, NovagramSendConfirmStrings.toggleTitle(langCode: langCode), NovagramSendConfirmStrings.toggleSubtitle(langCode: langCode), state.sendConfirmEnabled, false))
    entries.append(.enableNovagramProxy(presentationData.theme, NovagramProxyStrings.toggleTitle(langCode: langCode), NovagramProxyStrings.toggleSubtitle(langCode: langCode), state.enableNovagramProxy))
    entries.append(.protectionFooter(presentationData.theme, l10n.settings_protection_footer))

    // ─── APPEARANCE (Feature #23) ───
    // Local strings — not in NovagramL10n to avoid parallel-edit hazard on Localization module.
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    let appearanceTitle = NovagramWhiteThemeStrings.sectionTitle(langCode: langCode)
    let accentTitle    = NovagramWhiteThemeStrings.toggleTitle(langCode: langCode)
    let accentSubtitle = NovagramWhiteThemeStrings.toggleSubtitle(langCode: langCode)
    let accentFooter   = NovagramWhiteThemeStrings.footer(langCode: langCode)
    entries.append(.appearanceHeader(appearanceTitle))
    entries.append(.whiteThemeAccent(presentationData.theme, accentTitle, accentSubtitle, state.whiteThemeAccentEnabled, false))
    entries.append(.appearanceFooter(presentationData.theme, accentFooter))

    // ─── CHAT LOCK (Feature #46) ───
    // Informational section — lock is set per-chat via long-press context menu, not via a global toggle here.
    // Local strings to avoid parallel-edit hazard on the shared Localization module.
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    entries.append(.chatLockHeader(NovagramSettingsChatLockStrings.sectionTitle(langCode: langCode), false))
    entries.append(.chatLockInfo(presentationData.theme, NovagramSettingsChatLockStrings.infoBody(langCode: langCode)))
    entries.append(.chatLockFooter(presentationData.theme, NovagramSettingsChatLockStrings.footer(langCode: langCode)))
    entries.append(.secretVaultEnabled(presentationData.theme, SecretVaultStrings.settingsTitle(langCode: langCode), SecretVaultStrings.settingsSubtitle(langCode: langCode), state.secretVaultEnabled, true))
    // Biometric unlock row: only when a vault PIN exists AND the device has biometrics enrolled.
    if state.secretVaultEnabled, let biometricKind = SecretVaultBiometric.availableType() {
        let isFaceID = biometricKind == .faceID
        entries.append(.secretVaultBiometric(presentationData.theme, SecretVaultStrings.biometricToggleTitle(faceID: isFaceID), isFaceID ? "faceid" : "touchid", state.secretVaultBiometricEnabled))
        entries.append(.secretVaultFooter(presentationData.theme, SecretVaultStrings.biometricFooter))
    } else {
        entries.append(.secretVaultFooter(presentationData.theme, SecretVaultStrings.settingsFooter(langCode: langCode)))
    }

    // ─── UNREAD MESSAGE REMINDER (Xabar eslatmasi) ───
    // isNew: hardcoded true — set to false here when this feature is no longer new.
    entries.append(.reminderHeader(l10n.settings_reminder_sectionTitle, false))
    entries.append(.reminderEnabled(presentationData.theme, l10n.settings_reminder_enabled_title, l10n.settings_reminder_enabled_subtitle, state.reminderEnabled))
    entries.append(.reminderTime(presentationData.theme, l10n.settings_reminder_time_title, l10n.settings_reminder_minutesLabel(state.reminderMinutes)))
    entries.append(.reminderSound(presentationData.theme, l10n.settings_reminder_sound_title, l10n.settings_reminder_soundName(state.reminderSound)))
    entries.append(.reminderFooter(presentationData.theme, l10n.settings_reminder_footer))

    // ─── FEATURES (#19, #21, #32, #40, #45) ───
    // isNew: hardcoded true — set to false here when this section is no longer new.
    entries.append(.featuresHeader(NovagramFeaturesStrings.sectionTitle(langCode: langCode), true))
    entries.append(.addRecommendedFolders(presentationData.theme, NovagramFeaturesStrings.addFoldersTitle(langCode: langCode), NovagramFeaturesStrings.addFoldersTip(langCode: langCode), false))
    entries.append(.foldersPrompt(presentationData.theme, NovagramFeaturesStrings.foldersPromptTitle(langCode: langCode), NovagramFeaturesStrings.foldersPromptTip(langCode: langCode), state.foldersPromptEnabled))
    entries.append(.adminFolders(presentationData.theme, NovagramAdminFoldersStrings.toggleTitle(langCode: langCode), NovagramAdminFoldersStrings.toggleSubtitle(langCode: langCode), state.adminFoldersEnabled, true))
    let folderStyleLabel = NovagramFeaturesStrings.folderStyleLabel(state.folderStyle, langCode: langCode)
    entries.append(.folderStyle(presentationData.theme, NovagramFeaturesStrings.folderStyleTitle(langCode: langCode), folderStyleLabel, false))
    entries.append(.channelHistoryButton(presentationData.theme, NovagramFeaturesStrings.channelHistoryTitle(langCode: langCode), NovagramFeaturesStrings.channelHistoryTip(langCode: langCode), state.channelHistoryEnabled, true))
    entries.append(.autoAcceptRequests(presentationData.theme, NovagramFeaturesStrings.autoAcceptTitle(langCode: langCode), NovagramFeaturesStrings.autoAcceptTip(langCode: langCode), state.autoAcceptEnabled, true))
    // Feature #40: always-visible "Share Novagram Settings link" button. The toggle was removed —
    // sharing a link needs no on/off switch, and deep-link handling (OpenResolvedUrl) is independent of it.
    entries.append(.shareNovagramProLink(presentationData.theme, NovagramFeaturesStrings.shareNovagramProLinkTitle(langCode: langCode)))
    entries.append(.storyUnlockEnabled(presentationData.theme, NovagramStoryUnlockStrings.toggleTitle(langCode: langCode), NovagramStoryUnlockStrings.toggleSubtitle(langCode: langCode), state.storyUnlockEnabled, true))
    entries.append(.translateChatsUnlock(presentationData.theme, NovagramTranslateUnlockStrings.toggleTitle(langCode: langCode), NovagramTranslateUnlockStrings.toggleSubtitle(langCode: langCode), state.translateChatsUnlock, true))
    // The hint is what makes the per-row link long-press discoverable — it has no other affordance.
    let featuresFooter = NovagramFeaturesStrings.footer(langCode: langCode) + " " + NovagramSettingsLinkStrings.longPressHint(langCode: langCode)
    entries.append(.featuresFooter(presentationData.theme, featuresFooter))

    // ─── DEVELOPER (hidden, revealed by a 20 s hold on the Settings version line) ───
    if state.developerSectionRevealed {
        entries.append(.developerHeader(NovagramDeveloperStrings.sectionTitle(langCode: langCode)))
        // "Remove all ads" is the inverse of the stored fenix_show_ads flag (ON = no ads at all).
        let role = state.developerRole
        if role.canUse(.removeAllAds) {
            entries.append(.showAds(presentationData.theme, NovagramDeveloperStrings.removeAdsTitle(langCode: langCode), NovagramDeveloperStrings.removeAdsTip(langCode: langCode), !state.showAds))
        }
        if role.canUse(.adEventsOff) {
            entries.append(.adEventsOff(presentationData.theme, NovagramDeveloperStrings.adEventsOffTitle(langCode: langCode), NovagramDeveloperStrings.adEventsOffTip(langCode: langCode), state.adEventsOff))
        }
        if role.canUse(.currencyRatesView) {
            entries.append(.currencyRatesView(presentationData.theme, NovagramDeveloperStrings.currencyRatesTitle(langCode: langCode), NovagramDeveloperStrings.currencyRatesTip(langCode: langCode), state.currencyRatesViewEnabled))
        }
        if role.canUse(.adsPanel) {
            entries.append(.adsPanel(presentationData.theme, NovagramDeveloperStrings.adsPanelTitle(langCode: langCode), NovagramDeveloperStrings.adsPanelTip(langCode: langCode), state.adsPanelEnabled))
        }
        if role.canUse(.callRecording) {
            entries.append(.developerBeta(presentationData.theme, .callRecording, NovagramDeveloperStrings.callRecordingTitle(langCode: langCode), state.devCallRecording))
        }
        if role.canUse(.callDataSaving) {
            entries.append(.developerBeta(presentationData.theme, .callDataSaving, NovagramDeveloperStrings.callDataSavingTitle(langCode: langCode), state.devCallDataSaving))
        }
        entries.append(.developerFooter(presentationData.theme, NovagramDeveloperStrings.footer(langCode: langCode)))
    }

    // ItemListController entries should arrive in stableId order to avoid an
    // assertion. Section visual order is controlled by stableId numbering.
    return entries.sorted()
}

private final class NovagramSettingsArguments {
    let openAccounts: () -> Void
    let openAbout: () -> Void
    let openNovagramBots: () -> Void
    let openCalls: () -> Void
    let updateShowDeletedMessages: (Bool) -> Void
    let updateHideFolders: (Bool) -> Void
    let updateShowStories: (Bool) -> Void
    let updateShowMutualContactSymbol: (Bool) -> Void
    let updateShowGhostMode: (Bool) -> Void
    let updateShowViewFirstMessage: (Bool) -> Void
    let updateLongPressCameraSelection: (Bool) -> Void
    let updateEditedHistoryEnabled: (Bool) -> Void
    let updateRoundVideoFromGallery: (Bool) -> Void
    let updateForwardHideNames: (Bool) -> Void
    let updateUnlimitedPins: (Bool) -> Void
    let updateCallDataSaving: (Bool) -> Void
    let updateTranslateMessages: (Bool) -> Void
    let openTranslationSettings: () -> Void
    let openTextStyleSettings: () -> Void
    let openAutoTextSettings: () -> Void
    let openAutoTranslateSettings: () -> Void
    let updateSttEnabled: (Bool) -> Void
    let openSttLanguageSettings: () -> Void
    let updateBlockForeignUsers: (Bool) -> Void
    let updateEnableNovagramProxy: (Bool) -> Void
    let updateChatLockMaster: (Bool) -> Void
    let updateSecretVault: (Bool) -> Void
    let updateSecretVaultBiometric: (Bool) -> Void
    let updateWhiteThemeAccent: (Bool) -> Void
    let updateVoiceTranslate: (Bool) -> Void
    let updateAutoDownloadDisabled: (Bool) -> Void
    let updateSendTranslateConfirm: (Bool) -> Void
    let updateSendConfirmEnabled: (Bool) -> Void
    let updateAutoStickerEnabled: (Bool) -> Void
    let updateHeartEffectEnabled: (Bool) -> Void
    let updateReminderEnabled: (Bool) -> Void
    let openReminderTimeSettings: () -> Void
    let openReminderSoundSettings: () -> Void
    // Features (#19, #21, #32, #40, #45)
    let addRecommendedFolders: () -> Void
    let openFolderStyle: () -> Void
    let updateChannelHistory: (Bool) -> Void
    let updateSettingsLinks: (Bool) -> Void
    let shareNovagramProLink: () -> Void
    let updateAutoAccept: (Bool) -> Void
    let updateAdminFolders: (Bool) -> Void
    let updateFoldersPrompt: (Bool) -> Void
    // Developer section (hidden)
    let updateShowAds: (Bool) -> Void
    let updateAdEventsOff: (Bool) -> Void
    let updateCurrencyRatesView: (Bool) -> Void
    let updateAdsPanel: (Bool) -> Void
    let updateStoryUnlock: (Bool) -> Void
    let updateTranslateChatsUnlock: (Bool) -> Void
    let openCarPlay: () -> Void
    // Call recording rows, set after init (HOOKS.md, "Call recording").
    var updateCallRecording: (Bool) -> Void = { _ in }
    var updateCallRecordingAuto: (Bool) -> Void = { _ in }
    var openCallRecordings: () -> Void = {}
    var updateDeveloperBeta: (NovagramDeveloperRole.Switch, Bool) -> Void = { _, _ in }

    init(openAccounts: @escaping () -> Void, openAbout: @escaping () -> Void, openNovagramBots: @escaping () -> Void, openCalls: @escaping () -> Void, updateShowDeletedMessages: @escaping (Bool) -> Void, updateHideFolders: @escaping (Bool) -> Void, updateShowStories: @escaping (Bool) -> Void, updateShowMutualContactSymbol: @escaping (Bool) -> Void, updateShowGhostMode: @escaping (Bool) -> Void, updateShowViewFirstMessage: @escaping (Bool) -> Void, updateLongPressCameraSelection: @escaping (Bool) -> Void, updateEditedHistoryEnabled: @escaping (Bool) -> Void, updateRoundVideoFromGallery: @escaping (Bool) -> Void, updateForwardHideNames: @escaping (Bool) -> Void, updateUnlimitedPins: @escaping (Bool) -> Void, updateCallDataSaving: @escaping (Bool) -> Void, updateTranslateMessages: @escaping (Bool) -> Void, openTranslationSettings: @escaping () -> Void, openTextStyleSettings: @escaping () -> Void, openAutoTextSettings: @escaping () -> Void, openAutoTranslateSettings: @escaping () -> Void, updateSttEnabled: @escaping (Bool) -> Void, openSttLanguageSettings: @escaping () -> Void, updateBlockForeignUsers: @escaping (Bool) -> Void, updateEnableNovagramProxy: @escaping (Bool) -> Void, updateChatLockMaster: @escaping (Bool) -> Void, updateSecretVault: @escaping (Bool) -> Void, updateSecretVaultBiometric: @escaping (Bool) -> Void, updateWhiteThemeAccent: @escaping (Bool) -> Void, updateVoiceTranslate: @escaping (Bool) -> Void, updateAutoDownloadDisabled: @escaping (Bool) -> Void, updateSendTranslateConfirm: @escaping (Bool) -> Void, updateSendConfirmEnabled: @escaping (Bool) -> Void, updateAutoStickerEnabled: @escaping (Bool) -> Void, updateHeartEffectEnabled: @escaping (Bool) -> Void, updateReminderEnabled: @escaping (Bool) -> Void, openReminderTimeSettings: @escaping () -> Void, openReminderSoundSettings: @escaping () -> Void, addRecommendedFolders: @escaping () -> Void, openFolderStyle: @escaping () -> Void, updateChannelHistory: @escaping (Bool) -> Void, updateSettingsLinks: @escaping (Bool) -> Void, shareNovagramProLink: @escaping () -> Void, updateAutoAccept: @escaping (Bool) -> Void, updateAdminFolders: @escaping (Bool) -> Void, updateFoldersPrompt: @escaping (Bool) -> Void, updateShowAds: @escaping (Bool) -> Void, updateAdEventsOff: @escaping (Bool) -> Void, updateCurrencyRatesView: @escaping (Bool) -> Void, updateAdsPanel: @escaping (Bool) -> Void, updateStoryUnlock: @escaping (Bool) -> Void, updateTranslateChatsUnlock: @escaping (Bool) -> Void, openCarPlay: @escaping () -> Void) {
        self.openAccounts = openAccounts
        self.openAbout = openAbout
        self.openNovagramBots = openNovagramBots
        self.openCalls = openCalls
        self.updateShowDeletedMessages = updateShowDeletedMessages
        self.updateHideFolders = updateHideFolders
        self.updateShowStories = updateShowStories
        self.updateShowMutualContactSymbol = updateShowMutualContactSymbol
        self.updateShowGhostMode = updateShowGhostMode
        self.updateShowViewFirstMessage = updateShowViewFirstMessage
        self.updateLongPressCameraSelection = updateLongPressCameraSelection
        self.updateEditedHistoryEnabled = updateEditedHistoryEnabled
        self.updateRoundVideoFromGallery = updateRoundVideoFromGallery
        self.updateForwardHideNames = updateForwardHideNames
        self.updateUnlimitedPins = updateUnlimitedPins
        self.updateCallDataSaving = updateCallDataSaving
        self.updateTranslateMessages = updateTranslateMessages
        self.openTranslationSettings = openTranslationSettings
        self.openTextStyleSettings = openTextStyleSettings
        self.openAutoTextSettings = openAutoTextSettings
        self.openAutoTranslateSettings = openAutoTranslateSettings
        self.updateSttEnabled = updateSttEnabled
        self.openSttLanguageSettings = openSttLanguageSettings
        self.updateBlockForeignUsers = updateBlockForeignUsers
        self.updateEnableNovagramProxy = updateEnableNovagramProxy
        self.updateChatLockMaster = updateChatLockMaster
        self.updateSecretVault = updateSecretVault
        self.updateSecretVaultBiometric = updateSecretVaultBiometric
        self.updateWhiteThemeAccent = updateWhiteThemeAccent
        self.updateVoiceTranslate = updateVoiceTranslate
        self.updateAutoDownloadDisabled = updateAutoDownloadDisabled
        self.updateSendTranslateConfirm = updateSendTranslateConfirm
        self.updateSendConfirmEnabled = updateSendConfirmEnabled
        self.updateAutoStickerEnabled = updateAutoStickerEnabled
        self.updateHeartEffectEnabled = updateHeartEffectEnabled
        self.updateReminderEnabled = updateReminderEnabled
        self.openReminderTimeSettings = openReminderTimeSettings
        self.openReminderSoundSettings = openReminderSoundSettings
        self.addRecommendedFolders = addRecommendedFolders
        self.openFolderStyle = openFolderStyle
        self.updateChannelHistory = updateChannelHistory
        self.updateSettingsLinks = updateSettingsLinks
        self.shareNovagramProLink = shareNovagramProLink
        self.updateAutoAccept = updateAutoAccept
        self.updateAdminFolders = updateAdminFolders
        self.updateFoldersPrompt = updateFoldersPrompt
        self.updateShowAds = updateShowAds
        self.updateAdEventsOff = updateAdEventsOff
        self.updateCurrencyRatesView = updateCurrencyRatesView
        self.updateAdsPanel = updateAdsPanel
        self.updateStoryUnlock = updateStoryUnlock
        self.updateTranslateChatsUnlock = updateTranslateChatsUnlock
        self.openCarPlay = openCarPlay
    }
}

/// `highlightFeature` is set only when the screen was opened from a per-feature deep link
/// (`tg://settings/novagrampro/<slug>`). It scrolls that row into view and traces an outline
/// around it. Opening Settings normally leaves it nil — no scrolling, no animation.
public func novagramSettingsController(context: AccountContext, highlightFeature: NovagramSettingsFeature? = nil) -> ViewController {
    let statePromise = ValuePromise(NovagramSettingsState(), ignoreRepeated: true)
    let stateValue = Atomic(value: NovagramSettingsState())
    let updateState: ((NovagramSettingsState) -> NovagramSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    // Feature #46: presents the plain-UIKit ChatPincodeViewController navVC on the app's root VC.
    // Display's present path can't host a raw UINavigationController, so we go through the window.
    var presentPincodeControllerImpl: ((UIViewController) -> Void)?

    // Feature #46: re-read the keychain-backed master state into the toggle. Called after the
    // set/verify modal dismisses (success OR cancel) so the switch always reflects reality.
    let refreshChatLockMaster: () -> Void = {
        updateState { state in
            var state = state
            state.chatLockMasterEnabled = ChatPincodeManager.shared.isMasterEnabled()
            return state
        }
    }

    let refreshTranslateConfirmTarget: () -> Void = {
        updateState { state in
            var state = state
            state.translateConfirmTargetLanguage = NovagramSendTranslate.confirmTargetLanguage()
            return state
        }
    }

    let refreshSecretVault: () -> Void = {
        SecretVaultManager.shared.invalidateEnabledCache()
        updateState { state in
            var state = state
            state.secretVaultEnabled = ChatPincodeManager.shared.isVaultEnabled()
            state.secretVaultBiometricEnabled = ChatPincodeManager.shared.getVaultMetadata().biometricEnabled
            return state
        }
    }

    let arguments = NovagramSettingsArguments(openAccounts: {
        pushControllerImpl?(novagramAccountsController(context: context))
    }, openAbout: {
        pushControllerImpl?(novagramAboutController(context: context))
    }, openNovagramBots: {
        pushControllerImpl?(novagramBotsController(context: context))
    }, openCalls: {
        pushControllerImpl?(CallListController(context: context, mode: .navigation))
    }, updateShowDeletedMessages: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_deleted_messages")
        // The notification extension can only see the App Group suite, and it is the process that
        // handles the MESSAGE_DELETED push while the app is backgrounded.
        NovagramSharedDefaults.syncShowDeletedMessages()
        NotificationCenter.default.post(name: .novagramShowDeletedChanged, object: nil)
        updateState { state in
            var state = state
            state.showDeletedMessages = value
            return state
        }
    }, updateHideFolders: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "hide_folders")
        NotificationCenter.default.post(name: NSNotification.Name("NovagramSettingsChanged"), object: nil)
        updateState { state in
            var state = state
            state.hideFolders = value
            return state
        }
    }, updateShowStories: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_stories")
        NotificationCenter.default.post(name: NSNotification.Name("NovagramSettingsChanged"), object: nil)
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
        NotificationCenter.default.post(name: NSNotification.Name("NovagramSettingsChanged"), object: nil)
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
    }, updateRoundVideoFromGallery: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "round_video_from_gallery")
        updateState { state in
            var state = state
            state.roundVideoFromGallery = value
            return state
        }
    }, updateForwardHideNames: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "forward_hide_names")
        updateState { state in
            var state = state
            state.forwardHideNames = value
            return state
        }
    }, updateUnlimitedPins: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "unlimited_pins")
        if !value {
            // Turning it off drops the device-local pins outright. Keeping them while the feature
            // is off would mean tracking a list that quietly drifts from reality — chats unpinned
            // on another device, deleted, archived — for no benefit. The synced ones are untouched.
            //
            // Clearing the store is not enough on its own: those chats are still pinned in Postbox
            // and nothing would ever unpin them, so the user would watch an "off" that changed
            // nothing. Trim the list back to what the server already holds.
            // Order matters. startStandalone only QUEUES the transaction, and the trim has to read
            // the store back to know which ids it added. Clearing the store synchronously here
            // emptied it first, so the trim found nothing and silently unpinned nothing. Clear the
            // remaining accounts only once it has finished; it clears the active account itself.
            _ = context.engine.peers.novagramTrimPinnedChatsToServerLimit().startStandalone(completed: {
                NovagramLocalPins.clearAllAccounts()
            })
        }
        updateState { state in
            var state = state
            state.unlimitedPins = value
            return state
        }
    }, updateCallDataSaving: { value in
        NovagramCallDataSaving.set(value, accountManager: context.sharedContext.accountManager)
    }, updateTranslateMessages: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "show_translate_messages")
        updateState { state in
            var state = state
            state.showTranslateMessages = value
            return state
        }
    }, openTranslationSettings: {
        pushControllerImpl?(novagramTranslationController(context: context))
    }, openTextStyleSettings: {
        pushControllerImpl?(novagramTextStyleController(context: context, onStyleSelected: { newStyle in
            updateState { state in
                var state = state
                state.textStyle = newStyle
                return state
            }
        }))
    }, openAutoTextSettings: {
        pushControllerImpl?(novagramAutoTextController(context: context, onEnabledSelected: { isEnabled in
            updateState { state in
                var state = state
                state.autoTextEnabled = isEnabled
                return state
            }
        }))
    }, openAutoTranslateSettings: {
        pushControllerImpl?(novagramTranslateAutoController(context: context, onEnabledSelected: { isEnabled in
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
    }, updateEnableNovagramProxy: { value in
        NovagramAutoProxyManager.shared.setEnabled(value, sharedContext: context.sharedContext)
        updateState { state in
            var state = state
            state.enableNovagramProxy = value
            return state
        }
    }, updateChatLockMaster: { value in
        // Feature #46: Chat Lock master toggle.
        // Optimistically reflect the user's intent so the switch animates immediately; the true
        // state is reconciled from ChatPincodeManager after the modal dismisses (see didAppear).
        // The optimistic value also guarantees a state change on cancel, so the deferred refresh
        // re-renders the row and snaps the switch back.
        updateState { state in
            var state = state
            state.chatLockMasterEnabled = value
            return state
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let pincodeVC: ChatPincodeViewController
        if value {
            // Turning ON — set a master pincode.
            pincodeVC = ChatPincodeViewController(mode: .set(onSuccess: { code, type, bio in
                ChatPincodeManager.shared.setMasterPincode(code, type: type, biometricEnabled: bio)
                // Reflect the real master state the instant it changes. The didAppear timer alone
                // races the modal's dismiss completion (which is where this runs) and can read the
                // pre-set value, leaving the switch off until the page is reopened.
                Queue.mainQueue().async { refreshChatLockMaster() }
            }), presentationData: presentationData)
        } else {
            // Turning OFF — verify the master, then wipe every lock so nothing is stranded.
            let meta = ChatPincodeManager.shared.getMasterMetadata()
            pincodeVC = ChatPincodeViewController(mode: .verify(passwordType: meta.passwordType, biometricEnabled: meta.biometricEnabled, onVerify: { code in
                ChatPincodeManager.shared.verifyMaster(code)
            }, onSuccess: {
                ChatPincodeManager.shared.disableChatLock()
                Queue.mainQueue().async { refreshChatLockMaster() }
            }), presentationData: presentationData)
        }
        let navVC = UINavigationController(rootViewController: pincodeVC)
        navVC.setNavigationBarHidden(true, animated: false)
        navVC.modalPresentationStyle = .fullScreen
        presentPincodeControllerImpl?(navVC)
    }, updateSecretVault: { value in
        // Secret Vault toggle — an independent PIN. ON sets it; OFF verifies, then
        // unhides + unmutes every vaulted chat and removes the vault PIN.
        updateState { state in
            var state = state
            state.secretVaultEnabled = value
            return state
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let pincodeVC: ChatPincodeViewController
        if value {
            pincodeVC = ChatPincodeViewController(mode: .set(onSuccess: { code, type, bio in
                ChatPincodeManager.shared.setVaultPincode(code, type: type, biometricEnabled: bio)
                Queue.mainQueue().async { refreshSecretVault() }
            }), presentationData: presentationData)
        } else {
            let meta = ChatPincodeManager.shared.getVaultMetadata()
            pincodeVC = ChatPincodeViewController(mode: .verify(passwordType: meta.passwordType, biometricEnabled: meta.biometricEnabled, onVerify: { code in
                ChatPincodeManager.shared.verifyVault(code)
            }, onSuccess: {
                // Restore the global category default (nil). Passing 0 would write an explicit
                // per-peer unmute for every vaulted chat, overriding "Group Chats / Channels: off".
                for peerId in SecretVaultManager.shared.vaultedPeerIds() {
                    _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: nil).startStandalone()
                }
                SecretVaultManager.shared.clearVault()
                ChatPincodeManager.shared.removeVault()
                Queue.mainQueue().async { refreshSecretVault() }
            }), presentationData: presentationData)
        }
        let navVC = UINavigationController(rootViewController: pincodeVC)
        navVC.setNavigationBarHidden(true, animated: false)
        navVC.modalPresentationStyle = .fullScreen
        presentPincodeControllerImpl?(navVC)
    }, updateSecretVaultBiometric: { value in
        // Persist the vault biometric flag. Turning it ON runs a one-time biometric
        // confirmation so the user proves it works; on cancel/failure we revert the
        // switch. The PIN/text entry stays the fallback at vault-open time, so a
        // biometric failure can never lock the user out of the vault.
        if value {
            SecretVaultBiometric.authenticateBiometricsOnly(reason: SecretVaultStrings.biometricReason) { success in
                if success {
                    ChatPincodeManager.shared.setVaultBiometricEnabled(true)
                }
                updateState { state in
                    var state = state
                    state.secretVaultBiometricEnabled = success
                    return state
                }
            }
        } else {
            ChatPincodeManager.shared.setVaultBiometricEnabled(false)
            updateState { state in
                var state = state
                state.secretVaultBiometricEnabled = false
                return state
            }
        }
    }, updateWhiteThemeAccent: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "white_theme_accent_enabled")
        // Apply (or revert) the brand emerald accent on the light builtin themes.
        // The theme engine rebuilds presentationData app-wide — no restart needed.
        NovagramWhiteThemeAccent.applyToLightThemes(accountManager: context.sharedContext.accountManager, enabled: value)
        NotificationCenter.default.post(name: .novagramWhiteThemeAccentChanged, object: nil)
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
    }, updateAutoDownloadDisabled: { value in
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "auto_download_disabled")
        // When the switch is on, disable auto-download on every network; off restores it.
        _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
            var updated = current
            updated.cellular.enabled = !value
            updated.wifi.enabled = !value
            return updated
        }).start()
        updateState { state in
            var state = state
            state.autoDownloadDisabled = value
            return state
        }
    }, updateSendTranslateConfirm: { value in
        // Feature #37: yuborishdan oldin tarjima tasdiq so'rovi
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "translate_confirm_enabled")
        // Mutual-exclusive with voice auto-translate: enabling ask-on-send turns voice translate off.
        if value {
            UserDefaults(suiteName: "pro_messager")?.set(false, forKey: "voice_translate_enabled")
        }
        updateState { state in
            var state = state
            state.translateConfirmEnabled = value
            if value { state.voiceTranslateEnabled = false }
            return state
        }
    }, updateSendConfirmEnabled: { value in
        // Feature #38: yuborishdan oldin umumiy tasdiq so'rovi (ovoz, stiker, sovg'a)
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "send_confirm_enabled")
        updateState { state in
            var state = state
            state.sendConfirmEnabled = value
            return state
        }
    }, updateAutoStickerEnabled: { value in
        // Feature #30: Sticker auto-add toggle
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "auto_sticker_enabled")
        if !value {
            // When disabled, clear saved sticker data to avoid stale state
            UserDefaults(suiteName: "pro_messager")?.removeObject(forKey: "auto_sticker_data")
        }
        updateState { state in
            var state = state
            state.autoStickerEnabled = value
            return state
        }
    }, updateHeartEffectEnabled: { value in
        // Feature #34: Heart effect toggle — on enable, resolve & cache the ❤️ effect id for the send path
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "heart_effect_enabled")
        if value {
            NovagramHeartEffect.resolveAndCache(context: context)
        }
        updateState { state in
            var state = state
            state.heartEffectEnabled = value
            return state
        }
    }, updateReminderEnabled: { value in
        // Unread message reminder (Xabar eslatmasi) master toggle
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "unread_reminder_enabled")
        updateState { state in
            var state = state
            state.reminderEnabled = value
            return state
        }
    }, openReminderTimeSettings: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let l10n = NovagramL10n(presentationData.strings)
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var selectedMinutes = stateValue.with { $0.reminderMinutes }
        let pickerItem = NovagramReminderMinutePickerItem(
            initialMinutes: selectedMinutes,
            titleForRow: { minutes in l10n.settings_reminder_minutesLabel(minutes) },
            updated: { minutes in
                selectedMinutes = minutes
            }
        )
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [pickerItem]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Done, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    UserDefaults(suiteName: "pro_messager")?.set(selectedMinutes, forKey: "unread_reminder_minutes")
                    updateState { state in
                        var state = state
                        state.reminderMinutes = selectedMinutes
                        return state
                    }
                }),
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .default, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }, openReminderSoundSettings: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let l10n = NovagramL10n(presentationData.strings)
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var selectedSound = stateValue.with { $0.reminderSound }

        // One selectable sound row. Tapping it previews the tone, persists the choice,
        // and moves the checkmark IN PLACE via updateItem — it must NOT rebuild the whole
        // sheet. Rebuilding (setItemGroups) from inside a row's own tap tore down the very
        // node being tapped mid-touch, which blacked out the sheet and froze it.
        func makeSoundItem(_ key: String) -> ActionSheetCheckboxItem {
            return ActionSheetCheckboxItem(
                title: l10n.settings_reminder_soundName(key),
                label: "",
                value: selectedSound == key,
                action: { [weak actionSheet] _ in
                    let previous = selectedSound
                    selectedSound = key
                    NovagramReminderSoundPreview.shared.play(key: key)
                    UserDefaults(suiteName: "pro_messager")?.set(key, forKey: "unread_reminder_sound")
                    updateState { state in
                        var state = state
                        state.reminderSound = key
                        return state
                    }
                    // Only the two affected rows change: uncheck the old, check the new.
                    // updateItem reuses each existing node (no teardown → safe mid-tap).
                    let options = NovagramUnreadReminderSettings.soundOptions
                    if previous != key, let prevIndex = options.firstIndex(of: previous) {
                        actionSheet?.updateItem(groupIndex: 0, itemIndex: prevIndex) { _ in makeSoundItem(previous) }
                    }
                    if let newIndex = options.firstIndex(of: key) {
                        actionSheet?.updateItem(groupIndex: 0, itemIndex: newIndex) { _ in makeSoundItem(key) }
                    }
                }
            )
        }

        let soundItems: [ActionSheetItem] = NovagramUnreadReminderSettings.soundOptions.map { makeSoundItem($0) }
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: soundItems),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Done, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }, addRecommendedFolders: {
        // Feature #19: add recommended folders; show a brief confirmation alert on success.
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        NovagramRecommendedFolders.addIfNeeded(context: context) { added in
            guard added else { return }
            let alert = textAlertController(
                context: context,
                title: nil,
                text: NovagramFeaturesStrings.addedToastMessage(langCode: langCode),
                actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
            )
            presentControllerImpl?(alert)
        }
    }, openFolderStyle: {
        // Feature #21: folder display style picker (icon / text / auto)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let styles: [(String, String)] = [
            ("icon", NovagramFeaturesStrings.folderStyleLabel("icon", langCode: langCode)),
            ("text", NovagramFeaturesStrings.folderStyleLabel("text", langCode: langCode)),
            ("auto", NovagramFeaturesStrings.folderStyleLabel("auto", langCode: langCode))
        ]
        var styleItems: [ActionSheetItem] = []
        for (key, name) in styles {
            styleItems.append(ActionSheetButtonItem(title: name, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                UserDefaults(suiteName: "pro_messager")?.set(key, forKey: "fenix_folder_display_style")
                updateState { state in
                    var state = state
                    state.folderStyle = key
                    return state
                }
                // Feature #21: rebuild the chat-list filter tabs live so the new
                // style applies immediately (observed in ChatListController).
                NotificationCenter.default.post(name: NSNotification.Name("NovagramSettingsChanged"), object: nil)
            }))
        }
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: styleItems),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }, updateChannelHistory: { value in
        // Feature #32: channel history button — scaffold (behavior in later phase)
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "fenix_channel_history_button")
        updateState { state in
            var state = state
            state.channelHistoryEnabled = value
            return state
        }
    }, updateSettingsLinks: { value in
        // Feature #40: settings links toggle — saves state; also shows/hides the share row
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "fenix_settings_links")
        updateState { state in
            var state = state
            state.settingsLinksEnabled = value
            return state
        }
    }, shareNovagramProLink: {
        // Feature #40 (part b): copy tg://settings/novagrampro to clipboard and present share sheet.
        // This row always shares the whole-screen link; per-row links come from a long press.
        let link = NovagramSettingsDeepLink.screenLink
        UIPasteboard.general.string = link
        let shareController = context.sharedContext.makeShareController(
            context: context,
            params: ShareControllerParams(subject: .url(link))
        )
        presentControllerImpl?(shareController)
    }, updateAutoAccept: { value in
        // Feature #45: auto-accept join requests for admin channels/groups.
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "fenix_autoaccept_global")
        // Start/stop the proactive monitor immediately so enabling it triggers an instant scan
        // rather than waiting for the next chat open or app relaunch.
        if value {
            NovagramAutoAcceptManager.startGlobalMonitor(context: context)
        } else {
            NovagramAutoAcceptManager.stopGlobalMonitor()
        }
        updateState { state in
            var state = state
            state.autoAcceptEnabled = value
            return state
        }
    }, updateAdminFolders: { value in
        // Feature #47: auto-managed owner/admin folders. The manager owns the UserDefaults
        // key so enable/disable stay a single code path (AppDelegate re-enters via
        // startGlobalMonitor on the next launch).
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        if value {
            NovagramAdminFoldersManager.enable(context: context, completion: { outcome in
                let text: String
                switch outcome {
                case let .foldersReady(created, _):
                    text = created > 0 ? NovagramAdminFoldersStrings.createdAlert(count: created, langCode: langCode) : NovagramAdminFoldersStrings.upToDateAlert(langCode: langCode)
                case .nothingToManage:
                    text = NovagramAdminFoldersStrings.emptyAlert(langCode: langCode)
                }
                let alert = textAlertController(
                    context: context,
                    title: nil,
                    text: text,
                    actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
                )
                presentControllerImpl?(alert)
            })
        } else {
            NovagramAdminFoldersManager.disable(context: context)
        }
        updateState { state in
            var state = state
            state.adminFoldersEnabled = value
            return state
        }
    }, updateFoldersPrompt: { value in
        NovagramRecommendedFolders.isFirstLaunchPromptEnabled = value
        updateState { state in
            var state = state
            state.foldersPromptEnabled = value
            return state
        }
    }, updateShowAds: { value in
        // Feature #6: Ads toggle — writes the key that ChatHistoryListNode reads.
        // true (default) = sponsored messages shown; false = suppressed.
        UserDefaults(suiteName: "pro_messager")?.set(value, forKey: "fenix_show_ads")
        // Reactive: notify open chats so the ads gate re-reads live (no reopen needed).
        NotificationCenter.default.post(name: .novagramShowAdsChanged, object: nil)
        updateState { state in
            var state = state
            state.showAds = value
            return state
        }
    }, updateAdEventsOff: { value in
        NovagramDeveloperFlags.isAdEventsOff = value
        updateState { state in
            var state = state
            state.adEventsOff = value
            return state
        }
    }, updateCurrencyRatesView: { value in
        NovagramDeveloperFlags.isCurrencyRatesViewEnabled = value
        updateState { state in
            var state = state
            state.currencyRatesViewEnabled = value
            return state
        }
    }, updateAdsPanel: { value in
        NovagramDeveloperFlags.isAdsPanelEnabled = value
        updateState { state in
            var state = state
            state.adsPanelEnabled = value
            return state
        }
    }, updateStoryUnlock: { value in
        // Turning ON asks first; turning OFF is immediate. NovagramStoryUnlock.isEnabled is the
        // single source of truth every hook site reads, so it is written only after confirmation —
        // if the user cancels, the switch snaps back because state never changed.
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        if !value {
            NovagramStoryUnlock.isEnabled = false
            updateState { state in
                var state = state
                state.storyUnlockEnabled = false
                return state
            }
            return
        }
        // ItemListSwitchItem flips itself the moment it is tapped, so the switch is already
        // visually ON while the alert is up. Move STATE to match, or the row and the switch
        // disagree; then put both back if the user declines. Without this, Cancel left the
        // switch green while nothing was ever written.
        updateState { state in
            var state = state
            state.storyUnlockEnabled = true
            return state
        }
        let revert: () -> Void = {
            updateState { state in
                var state = state
                state.storyUnlockEnabled = false
                return state
            }
        }
        let alert = textAlertController(
            context: context,
            title: NovagramStoryUnlockStrings.warningTitle(langCode: langCode),
            text: NovagramStoryUnlockStrings.warningText(langCode: langCode),
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    revert()
                }),
                TextAlertAction(type: .defaultAction, title: NovagramStoryUnlockStrings.warningConfirm(langCode: langCode), action: {
                    NovagramStoryUnlock.isEnabled = true
                })
            ],
            // The two buttons are the only exits — an outside tap would otherwise dismiss without
            // running either action and strand the switch ON with storage still OFF.
            dismissOnOutsideTap: false
        )
        presentControllerImpl?(alert)
    }, updateTranslateChatsUnlock: { value in
        NovagramPremiumUnlock.isTranslateChatsUnlocked = value
        updateState { state in
            var state = state
            state.translateChatsUnlock = value
            return state
        }
    }, openCarPlay: {
        pushControllerImpl?(novagramCarPlayController(context: context))
    })
    arguments.updateCallRecording = { value in
        NovagramCallRecordingSettings.isUserEnabled = value
        updateState { state in
            var state = state
            state.callRecording = value
            return state
        }
    }
    arguments.updateCallRecordingAuto = { value in
        NovagramCallRecordingSettings.isUserAutoEnabled = value
        updateState { state in
            var state = state
            state.callRecordingAuto = value
            return state
        }
    }
    arguments.openCallRecordings = {
        pushControllerImpl?(novagramCallRecordingsController(context: context))
    }
    // The Developer beta gates. The setters post .novagramDeveloperFlagsChanged; the observer below re-reads them.
    arguments.updateDeveloperBeta = { item, value in
        switch item {
        case .callRecording:
            NovagramDeveloperFlags.isCallRecordingEnabled = value
        case .callDataSaving:
            NovagramDeveloperFlags.isCallDataSavingEnabled = value
        case .removeAllAds, .adEventsOff, .currencyRatesView, .adsPanel:
            break
        }
    }
    let refreshDeveloperFlags: () -> Void = {
        updateState { state in
            var state = state
            state.developerRole = NovagramDeveloperRole.current
            state.adEventsOff = NovagramDeveloperFlags.isAdEventsOff
            state.currencyRatesViewEnabled = NovagramDeveloperFlags.isCurrencyRatesViewEnabled
            state.adsPanelEnabled = NovagramDeveloperFlags.isAdsPanelEnabled
            state.devCallRecording = NovagramDeveloperFlags.isCallRecordingEnabled
            state.devCallDataSaving = NovagramDeveloperFlags.isCallDataSavingEnabled
            return state
        }
    }
    // Recordings are saved by calls and deleted on the list screen: recount them whenever Settings shows again.
    let refreshCallRecordings: () -> Void = {
        let count = NovagramCallRecordingStorage.list().count
        let isAutoEnabled = NovagramCallRecordingSettings.isUserAutoEnabled
        updateState { state in
            var state = state
            state.callRecordingCount = count
            state.callRecordingAuto = isAutoEnabled
            return state
        }
    }

    // Feature #40 (part c): the long-press share menu names the row the user pressed, so it needs
    // the titles of the rows currently on screen. They are only known once the entries are built.
    let latestEntries = Atomic<[NovagramEntry]>(value: [])
    let highlightTag: ItemListItemTag? = highlightFeature.map { NovagramSettingsItemTag(feature: $0) }

    // A call can turn auto-record off or save a recording while this screen stays open under the call UI.
    let callRecordingObserver = NotificationCenter.default.addObserver(forName: NovagramCallRecordingSettings.changedNotification, object: nil, queue: .main) { _ in
        refreshCallRecordings()
    }
    // A Developer switch flipped (here, or a login turned the hidden ones off): add or drop the gated rows.
    let developerFlagsObserver = NotificationCenter.default.addObserver(forName: .novagramDeveloperFlagsChanged, object: nil, queue: .main) { _ in
        refreshDeveloperFlags()
    }

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        NovagramCarPlayStatus.signal(context: context),
        NovagramCallDataSaving.isOnSignal(accountManager: context.sharedContext.accountManager)
    ) |> deliverOnMainQueue
        |> afterDisposed {
            NotificationCenter.default.removeObserver(callRecordingObserver)
            NotificationCenter.default.removeObserver(developerFlagsObserver)
        }
        |> map { presentationData, state, carPlayStatus, callDataSaving -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Novagram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let entries = novagramSettingsEntries(presentationData: presentationData, state: state, carPlayStatus: carPlayStatus, callDataSaving: callDataSaving)
            _ = latestEntries.swap(entries)
            // ensureVisibleItemTag only reaches rows whose nodes already exist, so a row far down
            // the list also needs an index-based scroll. ItemListNodeState applies this on the
            // first transition only, which is exactly the arrive-from-a-link moment.
            var initialScrollToItem: ListViewScrollToItem?
            if let highlightFeature, let index = entries.firstIndex(where: { $0.feature == highlightFeature }) {
                initialScrollToItem = ListViewScrollToItem(index: index, position: .center(.bottom), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
            }
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: highlightTag, initialScrollToItem: initialScrollToItem)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    presentPincodeControllerImpl = { [weak controller] vc in
        controller?.view.window?.rootViewController?.present(vc, animated: true)
    }

    controller.didAppear = { [weak controller] firstTime in
        guard let controller else { return }
        // Feature #46: after the Chat Lock set/verify modal dismisses (success OR cancel) the
        // settings screen re-appears — reconcile the toggle to the real master state. Deferred so
        // a successful set/disable (which runs in the modal's dismiss completion) lands first.
        Queue.mainQueue().after(0.3, {
            refreshChatLockMaster()
            refreshSecretVault()
            refreshTranslateConfirmTarget()
            refreshCallRecordings()
        })
        guard firstTime else { return }

        // Feature #40 (part c): press and hold any row to copy or share a link to that row.
        // The title closure reads the entries built for the current language and state, so the
        // sheet header always shows the row's own label.
        NovagramSettingsRowLinkMenu.attach(to: controller, context: context, title: { feature in
            return latestEntries.with { $0 }.first(where: { $0.feature == feature })?.linkInfo?.title
        })

        // Only when the screen was opened from a per-feature link — a normal open stays still.
        if let highlightFeature {
            let accentColor = context.sharedContext.currentPresentationData.with { $0 }.theme.list.itemAccentColor
            NovagramSettingsHighlight.run(controller: controller, feature: highlightFeature, accentColor: accentColor)
        }
    }

    return controller
}

// MARK: - Notification name (Feature #23)

extension NSNotification.Name {
    // Posted when the user flips the white-theme accent toggle.
    // Apply-point hook: subscribe to this in the place that rebuilds PresentationTheme
    // (e.g. inside the app's theme-override logic) and call
    // NovagramWhiteThemeAccent.applyIfNeeded(to:) there.
    public static let novagramWhiteThemeAccentChanged = NSNotification.Name("NovagramWhiteThemeAccentChanged")
}

// MARK: - Public read helper (Feature #23)

/// Lets any module read the white-theme-accent preference without importing NovagramMessenger
/// or referencing UserDefaults key literals directly.
public enum NovagramWhiteThemeAccent {
    // UserDefaults key — same suite as all other Novagram settings
    static let udKey   = "white_theme_accent_enabled"
    static let udSuite = "pro_messager"

    // Both light builtin themes get the accent: .dayClassic and .day.
    // For builtin themes PresentationThemeReference.index == the raw value (0 and 2).
    private static let lightThemeIndices: [Int64] = [
        PresentationThemeReference.builtin(.dayClassic).index,
        PresentationThemeReference.builtin(.day).index
    ]

    /// True when the user has turned on brand accent for the light theme.
    public static var isEnabled: Bool {
        UserDefaults(suiteName: udSuite)?.bool(forKey: udKey) ?? false
    }

    /// Returns NovagramBrandColors.lightThemeAccent when enabled, nil otherwise.
    public static func accentColorIfEnabled() -> UIColor? {
        guard isEnabled else { return nil }
        return NovagramBrandColors.lightThemeAccent
    }

    /// Writes (enabled) or reverts (disabled) the brand emerald accent on both light builtin themes.
    /// Disabling clears only the accent we set — a user-chosen accent is left untouched.
    /// Updating the shared theme settings makes the engine rebuild presentationData app-wide.
    public static func applyToLightThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, enabled: Bool) {
        let emerald = NovagramBrandColors.lightThemeAccentValue
        _ = updatePresentationThemeSettingsInteractively(accountManager: accountManager, { current in
            var accentColors = current.themeSpecificAccentColors
            for index in lightThemeIndices {
                if enabled {
                    accentColors[index] = PresentationThemeAccentColor(index: -1, baseColor: .custom, accentColor: emerald)
                } else if accentColors[index]?.accentColor == emerald {
                    accentColors[index] = nil
                }
            }
            return current.withUpdatedThemeSpecificAccentColors(accentColors)
        }).start()
    }
}

// MARK: - Local string namespace (Feature #23)
// Kept here to avoid the parallel-edit hazard on the shared Localization module.

private enum NovagramAutoDownloadStrings {
    static func title(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avto-yuklashni o'chirish"
        case "ru": return "Отключить автозагрузку"
        case "zh": return "关闭自动下载"
        default:   return "Disable auto-download"
        }
    }
    static func subtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Barcha media uchun avtomatik yuklab olishni o'chiradi (mobil va Wi-Fi)"
        case "ru": return "Отключает автозагрузку всех медиа (моб. сеть и Wi-Fi)"
        case "zh": return "在所有网络下关闭媒体自动下载"
        default:   return "Turns off media auto-download on all networks"
        }
    }
}

private enum NovagramProxyStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "NovagramProxy'ni yoqish"
        case "ru": return "Включить NovagramProxy"
        case "zh": return "开启 NovagramProxy"
        default:   return "Enable NovagramProxy"
        }
    }
    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Telegram bloklangan hududlarda avtomatik ulanish"
        case "ru": return "Автоподключение там, где Telegram заблокирован"
        case "zh": return "在 Telegram 被封锁的地区自动连接"
        default:   return "Automatic connection where Telegram is blocked"
        }
    }
}

private enum NovagramWhiteThemeStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ko'rinish"
        case "ru": return "Внешний вид"
        case "zh": return "外观"
        default:   return "Appearance"
        }
    }

    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yorqin temada brand rangi"
        case "ru": return "Акцент бренда в светлой теме"
        case "zh": return "浅色主题使用品牌强调色"
        default:   return "Brand accent in light theme"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yorqin (oq) temada Novagram ko'k rangini accent sifatida qo'llaydi"
        case "ru": return "Применяет фирменный синий Novagram в качестве акцента в светлой теме"
        case "zh": return "在浅色主题中使用 Novagram 蓝作为强调色"
        default:   return "Applies Novagram blue as the accent color in the light theme"
        }
    }

    static func footer(langCode: String) -> String {
        switch langCode {
        case "uz": return "Faqat yorqin (oq) temaga ta'sir qiladi. Qayta ishga tushirmasdan kuchga kiradi."
        case "ru": return "Влияет только на светлую тему. Применяется без перезапуска."
        case "zh": return "仅影响浅色主题，无需重启即可生效。"
        default:   return "Affects the light theme only. Takes effect without restarting."
        }
    }
}

// MARK: - Local string namespace (Feature #46 — Chat Lock)
// Kept local to avoid the parallel-edit hazard on the shared Localization module.
// Lock is set per-chat via long-press → context menu; this section is informational only.

private enum NovagramSettingsChatLockStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Chat qulfi"
        case "ru": return "Блокировка чата"
        case "zh": return "聊天锁"
        default:   return "Chat Lock"
        }
    }

    // Master toggle row (Protection section, Feature #46).
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Chat qulfi"
        case "ru": return "Блокировка чата"
        case "zh": return "聊天锁"
        default:   return "Chat Lock"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Asosiy pinkod o'rnating, so'ng chatlarni long-press menyusidan qulflang."
        case "ru": return "Установите главный пин-код, затем блокируйте отдельные чаты из меню по долгому нажатию."
        case "zh": return "先设置主密码，再通过长按菜单锁定单个聊天。"
        default:   return "Set a master pincode, then lock individual chats from their long-press menu."
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
        case "zh":
            return "长按任意聊天 → 在菜单中选择“设置密码”。" +
                   "你可以设置 4 位数字 PIN 码，或任意长度的字母数字密码。" +
                   "如果你的设备支持 Face ID 或 Touch ID，还可以开启生物识别解锁。" +
                   "打开已锁定的聊天时，需要输入密码或进行生物识别验证。"
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
        case "zh":
            return "每个聊天的锁需单独设置。密码保存在 iOS 钥匙串中。"
        default:
            return "Lock is set per-chat. Credentials are stored in the iOS Keychain."
        }
    }
}

// MARK: - Local string namespace (Feature #25 — Voice Translate)
// Kept local to avoid the parallel-edit hazard on the shared Localization module.
// Target language is reused from the existing auto_translate_lang key — no picker needed here.

private enum NovagramVoiceTranslateStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ovozli xabarlarni tarjima qilish"
        case "ru": return "Переводить голосовые сообщения"
        case "zh": return "翻译语音消息"
        default:   return "Translate voice messages"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Nutqni matnga aylantirgandan so'ng avtomatik tarjima qiladi. \"Yuborishda tarjima so'rovi\" o'chiq bo'lsa ishlaydi"
        case "ru": return "Автоматически переводит транскрипцию. Работает, когда «Запрос перевода при отправке» выключен"
        case "zh": return "自动翻译语音转写的文字。仅在“发送时询问翻译”关闭时生效"
        default:   return "Auto-translates the transcription. Works when \"Ask to translate on send\" is off"
        }
    }
}

// MARK: - Local string namespace (NEW badge header)
// Short localised text used as the badge label on section headers.
// "NEW" is kept very short so it fits cleanly in the grey header badge pill.

private enum NovagramNewBadgeLabel {
    static func headerText(langCode: String) -> String {
        switch langCode {
        case "uz": return "YANGI"
        case "ru": return "НОВОЕ"
        case "zh": return "新"
        default:   return "NEW"
        }
    }
}

// MARK: - Local string namespace (Feature #37 — Send-Translate Confirm)
// Kept local to avoid the parallel-edit hazard on the shared Localization module.
// The toggle sits in the Messaging section and controls translate_confirm_enabled key.

private enum NovagramSendTranslateStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuborishda tarjima so'rovi"
        case "ru": return "Запрос перевода при отправке"
        case "zh": return "发送时询问翻译"
        default:   return "Ask to translate on send"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Send tugmasida tarjima yoki original so'rovi chiqadi. Yoqilsa ovozli auto-tarjima o'chadi"
        case "ru": return "При отправке диалог: перевести или отправить. Включение отключает голосовой авто-перевод"
        case "zh": return "发送前弹窗询问是翻译后发送还是发送原文。开启后将关闭语音自动翻译"
        default:   return "Before sending, a dialog asks to translate or send original. Enabling turns off voice auto-translate"
        }
    }

    // The language comes from Auto-translate, else from Translation language (NovagramSendTranslate).
    static func targetLine(_ language: String, langCode: String) -> String {
        switch langCode {
        case "uz": return "Tarjima tili: \(language)"
        case "ru": return "Язык перевода: \(language)"
        case "zh": return "翻译成：\(language)"
        default:   return "Translates into \(language)"
        }
    }
}

// MARK: - Local string namespace (Feature #38 — Send Confirm Dialog)
// Ovoz xabari, stiker yoki sovg'a yuborishdan oldin tasdiq so'rovi.

public enum NovagramSendConfirmStrings {
    public static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuborishdan oldin so'rash"
        case "ru": return "Спрашивать перед отправкой"
        case "zh": return "发送前确认"
        default:   return "Ask before sending"
        }
    }

    public static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ovozli xabar, stiker yoki sovg'a yuborishdan oldin tasdiq so'raladi"
        case "ru": return "Перед отправкой голосового, стикера или подарка появится подтверждение"
        case "zh": return "发送语音消息、贴纸或礼物前需要确认"
        default:   return "Confirms before sending a voice message, sticker, or gift"
        }
    }

    public static func dialogTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuborishni tasdiqlang"
        case "ru": return "Подтвердите отправку"
        case "zh": return "确认发送"
        default:   return "Confirm sending"
        }
    }

    public static func dialogText(langCode: String) -> String {
        switch langCode {
        case "uz": return "Xabarni yuborishni xohlaysizmi?"
        case "ru": return "Вы хотите отправить это сообщение?"
        case "zh": return "要发送这条消息吗？"
        default:   return "Do you want to send this message?"
        }
    }

    public static func sendAction(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuborish"
        case "ru": return "Отправить"
        case "zh": return "发送"
        default:   return "Send"
        }
    }

    public static func cancelAction(langCode: String) -> String {
        switch langCode {
        case "uz": return "Bekor qilish"
        case "ru": return "Отмена"
        case "zh": return "取消"
        default:   return "Cancel"
        }
    }
}

// MARK: - Local string namespace (Feature #30 — Auto Sticker)
// Kept local to avoid parallel-edit hazard on the shared Localization module.

private enum NovagramAutoStickerStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avtomatik sticker"
        case "ru": return "Авто-стикер"
        case "zh": return "自动贴纸"
        default:   return "Auto sticker"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Har matnli xabardan keyin oxirgi yuborilgan stickerni qo'shadi"
        case "ru": return "После каждого текстового сообщения добавляет последний отправленный стикер"
        case "zh": return "每条文字消息后附加最近发送的贴纸"
        default:   return "Appends the last sent sticker after each text message"
        }
    }
}

// MARK: - Local string namespace (Feature #34 — Heart effect)

private enum NovagramHeartEffectStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yurakcha effekti"
        case "ru": return "Эффект сердечка"
        case "zh": return "爱心特效"
        default:   return "Heart effect"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuborilgan xabarlarga ❤️ animatsion effektini avtomatik qo'shadi"
        case "ru": return "Автоматически добавляет анимированный эффект ❤️ к отправленным сообщениям"
        case "zh": return "自动为发送的消息添加 ❤️ 动画特效"
        default:   return "Automatically adds the ❤️ animated effect to sent messages"
        }
    }
}

// MARK: - Feature #34: Heart effect resolver
// Resolves the server-assigned ❤️ message-effect id (free / non-premium reaction effect)
// and caches it to UserDefaults so the send path can attach it synchronously.
// availableMessageEffects() is a one-shot cached read, so we retry a few times in case
// the local cache isn't warm yet.
private enum NovagramHeartEffect {
    private static var disposable: Disposable?

    static func resolveAndCache(context: AccountContext) {
        attempt(context: context, remaining: 4)
    }

    private static func attempt(context: AccountContext, remaining: Int) {
        disposable?.dispose()
        disposable = (context.engine.stickers.availableMessageEffects()
        |> deliverOnMainQueue).start(next: { effects in
            if let effects = effects, !effects.messageEffects.isEmpty {
                let heart = effects.messageEffects.first(where: { $0.emoticon.hasPrefix("❤") && !$0.isPremium })
                    ?? effects.messageEffects.first(where: { $0.emoticon.hasPrefix("❤") })
                if let heart = heart {
                    UserDefaults(suiteName: "pro_messager")?.set(Int(heart.id), forKey: "fenix_heart_effect_id")
                }
            } else if remaining > 0 {
                Queue.mainQueue().after(1.5, {
                    attempt(context: context, remaining: remaining - 1)
                })
            }
        })
    }
}
