import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import NovagramLocalization

// CarPlay shows Novagram through SiriKit: Siri reads new messages aloud and sends the replies.
// The app has no CarPlay switch of its own, so whether CarPlay works comes down to the Siri
// permission, and that is the status this page shows.
enum NovagramCarPlayStatus: Equatable {
    case on
    case needsPermission
    // Denied, restricted, or a build without Siri. iOS shows its Siri prompt only once, so from
    // here only the Settings app can turn it back on.
    case blocked

    static func current(context: AccountContext) -> NovagramCarPlayStatus {
        switch context.sharedContext.applicationBindings.siriAuthorization() {
        case .allowed:
            return .on
        case .notDetermined:
            return .needsPermission
        default:
            return .blocked
        }
    }

    // Read again every time the app becomes active: that is the moment the user comes back
    // from the Settings app, and also when the system Siri prompt closes.
    static func signal(context: AccountContext) -> Signal<NovagramCarPlayStatus, NoError> {
        let onActive = context.sharedContext.applicationBindings.applicationIsActive
        |> filter { $0 }
        |> map { _ -> NovagramCarPlayStatus in
            return NovagramCarPlayStatus.current(context: context)
        }
        return (Signal<NovagramCarPlayStatus, NoError>.single(NovagramCarPlayStatus.current(context: context)) |> then(onActive))
        |> distinctUntilChanged
    }
}

// The status as the settings rows show it: green badge when on, red text when Siri is off.
func novagramCarPlayStatusLabel(_ status: NovagramCarPlayStatus, theme: PresentationTheme, strings: PresentationStrings) -> (String, ItemListDisclosureLabelStyle) {
    let l10n = NovagramL10n(strings)
    switch status {
    case .on:
        return (l10n.settings_state_enabled, .badge(NovagramIconColor.green.uiColor))
    case .needsPermission:
        return (l10n.settings_state_disabled, .text)
    case .blocked:
        let langCode = NovagramL10n.languageKey(for: strings)
        return (NovagramCarPlayStrings.siriOffLabel(langCode: langCode), .coloredText(theme.list.itemDestructiveColor))
    }
}

private final class NovagramCarPlayArguments {
    let enableCarPlay: () -> Void
    let openSettings: () -> Void

    init(enableCarPlay: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.enableCarPlay = enableCarPlay
        self.openSettings = openSettings
    }
}

private enum NovagramCarPlaySection: Int32 {
    case status
}

private enum NovagramCarPlayEntry: ItemListNodeEntry {
    case header(String)
    case status(PresentationTheme, String, NovagramCarPlayStatus)
    case action(PresentationTheme, String, NovagramCarPlayStatus)
    case footer(PresentationTheme, String)

    var section: ItemListSectionId {
        return NovagramCarPlaySection.status.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .status:
            return 1
        case .action:
            return 2
        case .footer:
            return 3
        }
    }

    static func == (lhs: NovagramCarPlayEntry, rhs: NovagramCarPlayEntry) -> Bool {
        switch lhs {
        case let .header(lhsText):
            if case let .header(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .status(lhsTheme, lhsTitle, lhsStatus):
            if case let .status(rhsTheme, rhsTitle, rhsStatus) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsStatus == rhsStatus { return true } else { return false }
        case let .action(lhsTheme, lhsTitle, lhsStatus):
            if case let .action(rhsTheme, rhsTitle, rhsStatus) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsStatus == rhsStatus { return true } else { return false }
        case let .footer(lhsTheme, lhsText):
            if case let .footer(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        }
    }

    static func < (lhs: NovagramCarPlayEntry, rhs: NovagramCarPlayEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramCarPlayArguments
        switch self {
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .status(theme, title, status):
            let (label, labelStyle) = novagramCarPlayStatusLabel(status, theme: theme, strings: presentationData.strings)
            let iconColor: NovagramIconColor = status == .on ? .green : (status == .blocked ? .red : .gray)
            return ItemListDisclosureItem(presentationData: presentationData, icon: novagramSettingsIcon(systemName: "car.fill", color: iconColor), title: title, label: label, labelStyle: labelStyle, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .action(_, title, status):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if status == .blocked {
                    arguments.openSettings()
                } else {
                    arguments.enableCarPlay()
                }
            })
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func novagramCarPlayEntries(presentationData: PresentationData, status: NovagramCarPlayStatus) -> [NovagramCarPlayEntry] {
    let langCode = NovagramL10n.languageKey(for: presentationData.strings)
    var entries: [NovagramCarPlayEntry] = []
    entries.append(.header(NovagramCarPlayStrings.title(langCode: langCode)))
    entries.append(.status(presentationData.theme, NovagramCarPlayStrings.title(langCode: langCode), status))
    switch status {
    case .on:
        entries.append(.footer(presentationData.theme, NovagramCarPlayStrings.footerOn(langCode: langCode)))
    case .needsPermission:
        entries.append(.action(presentationData.theme, NovagramCarPlayStrings.enableAction(langCode: langCode), status))
        entries.append(.footer(presentationData.theme, NovagramCarPlayStrings.footerNeedsPermission(langCode: langCode)))
    case .blocked:
        entries.append(.action(presentationData.theme, NovagramCarPlayStrings.openSettingsAction(langCode: langCode), status))
        entries.append(.footer(presentationData.theme, NovagramCarPlayStrings.footerBlocked(langCode: langCode)))
    }
    return entries
}

public func novagramCarPlayController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?

    // Bumped after the Siri request answers, in case the prompt closed without the app
    // going inactive and active again.
    let refreshCounter = Atomic<Int32>(value: 0)
    let refreshPromise = ValuePromise<Int32>(0, ignoreRepeated: false)
    let refreshStatus: () -> Void = {
        refreshPromise.set(refreshCounter.modify { $0 + 1 })
    }

    let arguments = NovagramCarPlayArguments(enableCarPlay: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let langCode = NovagramL10n.languageKey(for: presentationData.strings)
        // Say why Siri is needed before the one-time system prompt appears.
        let alert = textAlertController(
            context: context,
            title: NovagramCarPlayStrings.siriRequiredTitle(langCode: langCode),
            text: NovagramCarPlayStrings.siriRequiredText(langCode: langCode),
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .defaultAction, title: NovagramCarPlayStrings.continueAction(langCode: langCode), action: {
                    context.sharedContext.applicationBindings.requestSiriAuthorization { _ in
                        Queue.mainQueue().async {
                            refreshStatus()
                        }
                    }
                })
            ]
        )
        presentControllerImpl?(alert)
    }, openSettings: {
        context.sharedContext.applicationBindings.openSettings()
    })

    let statusSignal = combineLatest(NovagramCarPlayStatus.signal(context: context), refreshPromise.get())
    |> map { _, _ -> NovagramCarPlayStatus in
        return NovagramCarPlayStatus.current(context: context)
    }
    |> distinctUntilChanged

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statusSignal
    ) |> deliverOnMainQueue
        |> map { presentationData, status -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(NovagramCarPlayStrings.title(langCode: langCode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramCarPlayEntries(presentationData: presentationData, status: status), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Local string namespace (CarPlay)

enum NovagramCarPlayStrings {
    static func title(langCode: String) -> String {
        return "CarPlay"
    }

    static func siriOffLabel(langCode: String) -> String {
        switch langCode {
        case "uz": return "Siri o'chiq"
        case "ru": return "Siri выключена"
        case "zh": return "Siri 已关闭"
        default:   return "Siri is off"
        }
    }

    static func enableAction(langCode: String) -> String {
        switch langCode {
        case "uz": return "CarPlay'ni yoqish"
        case "ru": return "Включить CarPlay"
        case "zh": return "开启 CarPlay"
        default:   return "Enable CarPlay"
        }
    }

    static func openSettingsAction(langCode: String) -> String {
        switch langCode {
        case "uz": return "Sozlamalarni ochish"
        case "ru": return "Открыть настройки"
        case "zh": return "打开设置"
        default:   return "Open Settings"
        }
    }

    static func continueAction(langCode: String) -> String {
        switch langCode {
        case "uz": return "Davom etish"
        case "ru": return "Продолжить"
        case "zh": return "继续"
        default:   return "Continue"
        }
    }

    static func siriRequiredTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Siri kerak"
        case "ru": return "Нужна Siri"
        case "zh": return "需要 Siri"
        default:   return "Siri is required"
        }
    }

    static func siriRequiredText(langCode: String) -> String {
        switch langCode {
        case "uz": return "CarPlay'da Novagram xabarlarini Siri o'qib beradi va javobingizni yuboradi. Keyingi oynada Siri'ga ruxsat bering."
        case "ru": return "В CarPlay сообщения Novagram читает и отправляет Siri. Разрешите доступ к Siri в следующем окне."
        case "zh": return "在 CarPlay 中，Siri 会朗读 Novagram 消息并发送你的回复。请在接下来的窗口中允许 Siri 访问。"
        default:   return "In CarPlay, Siri reads your Novagram messages aloud and sends your replies. Allow Siri access in the next window."
        }
    }

    static func footerOn(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram CarPlay'ga tayyor. Mashinada Siri yangi xabarlarni ovoz chiqarib o'qiydi va javobingizni ovoz bilan yuboradi. Sinab ko'ring: «Hey Siri, read my Novagram messages»."
        case "ru": return "Novagram готов к CarPlay. В машине Siri читает новые сообщения вслух и отправляет ваши ответы голосом. Попробуйте: «Привет, Siri, прочитай сообщения в Novagram»."
        case "zh": return "Novagram 已可在 CarPlay 中使用。在车内，Siri 会朗读新消息，并用语音发送你的回复。"
        default:   return "Novagram is ready for CarPlay. In the car, Siri reads new messages aloud and sends your replies by voice. Try: “Hey Siri, read my Novagram messages.”"
        }
    }

    static func footerNeedsPermission(langCode: String) -> String {
        switch langCode {
        case "uz": return "CarPlay Siri orqali ishlaydi: Siri yangi xabarlarni o'qib beradi va javobingizni ovoz bilan yuboradi. «CarPlay'ni yoqish» ni bosing va Siri'ga ruxsat bering."
        case "ru": return "CarPlay работает через Siri: она читает новые сообщения и отправляет ваши ответы голосом. Нажмите «Включить CarPlay» и разрешите доступ к Siri."
        case "zh": return "CarPlay 通过 Siri 工作：Siri 朗读新消息，并用语音发送你的回复。点击“开启 CarPlay”并允许 Siri 访问。"
        default:   return "CarPlay works through Siri: Siri reads new messages aloud and sends your replies by voice. Tap “Enable CarPlay” and allow Siri access."
        }
    }

    static func footerBlocked(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram uchun Siri o'chirilgan, shuning uchun CarPlay xabarlarni o'qiy olmaydi va yubora olmaydi. iOS ruxsatni qayta so'rashga yo'l qo'ymaydi: «Sozlamalarni ochish» ni bosing, Siri bo'limida ruxsatni yoqing va ilovaga qayting, holat o'zi yangilanadi."
        case "ru": return "Siri для Novagram выключена, поэтому CarPlay не может читать и отправлять сообщения. iOS не позволяет запросить доступ повторно: нажмите «Открыть настройки», включите доступ в разделе Siri и вернитесь в приложение, статус обновится сам."
        case "zh": return "Novagram 的 Siri 已关闭，CarPlay 无法朗读或发送消息。iOS 不允许再次请求权限：点击“打开设置”，在 Siri 中开启访问，然后返回应用，状态会自动更新。"
        default:   return "Siri is turned off for Novagram, so CarPlay can't read or send messages. iOS doesn't allow asking again: tap “Open Settings”, turn on access under Siri, then come back and the status updates on its own."
        }
    }

    static func mainFooter(langCode: String) -> String {
        switch langCode {
        case "uz": return "Mashinada Novagram xabarlarini Siri o'qib beradi va javobingizni ovoz bilan yuboradi."
        case "ru": return "В машине Siri читает сообщения Novagram и отправляет ваши ответы голосом."
        case "zh": return "在车内，Siri 会朗读 Novagram 消息，并用语音发送你的回复。"
        default:   return "In the car, Siri reads your Novagram messages aloud and sends your replies by voice."
        }
    }
}
