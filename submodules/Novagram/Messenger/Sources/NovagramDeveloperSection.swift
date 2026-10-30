import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import NovagramLocalization
import NovagramCalls

// MARK: - Notification name

public extension NSNotification.Name {
    // Posted when a switch in the hidden Developer section flips, so the screens that read a flag
    // update live.
    static let novagramDeveloperFlagsChanged = NSNotification.Name("NovagramDeveloperFlagsChanged")
}

// MARK: - Flags

/// Switches from the hidden Developer section (Novagram Settings) for features that are not public
/// yet. They are per device and off by default. "Remove all ads", the first switch there, is read
/// through `NovagramShowAdsGate`.
public enum NovagramDeveloperFlags {
    private static let udSuite = "pro_messager"
    private static let currencyRatesViewKey = "novagram_currency_rates_view"
    private static let adsPanelKey = "novagram_ads_panel"
    // The beta gates for features that are not approved yet (same keys as the Mac). The call recording
    // key lives in its own module, which read them without depending on this one.
    private static let callDataSavingKey = "novagram_dev_call_data_saving"
    // TelegramCore reads this key directly (`novagramAdEventsOff()`), and the Mac app uses it too.
    private static let adEventsOffKey = "novagram_ads_events_off"

    /// "Don't send ad events": views, clicks, actions and video opens of Novagram and Telegram ads are
    /// not sent, so an ad the backend shows once per user keeps showing while a developer tests it.
    public static internal(set) var isAdEventsOff: Bool {
        get { return self.value(forKey: self.adEventsOffKey) }
        set { self.setValue(newValue, forKey: self.adEventsOffKey) }
    }

    /// Show the currency rates view.
    public static internal(set) var isCurrencyRatesViewEnabled: Bool {
        get { return self.value(forKey: self.currencyRatesViewKey) }
        set { self.setValue(newValue, forKey: self.currencyRatesViewKey) }
    }

    /// Show the Novagram ads panel.
    public static internal(set) var isAdsPanelEnabled: Bool {
        get { return self.value(forKey: self.adsPanelKey) }
        set { self.setValue(newValue, forKey: self.adsPanelKey) }
    }

    /// "Call recording (beta)": the call recording rows and the Record control (NovagramCallRecordingSettings).
    public static internal(set) var isCallRecordingEnabled: Bool {
        get { return NovagramCallRecordingSettings.isDeveloperEnabled }
        set { self.setValue(newValue, forKey: NovagramCallRecordingSettings.developerFlagKey) }
    }

    /// "Use less data for calls (beta)": our shortcut row to Telegram's call data saving setting.
    public static internal(set) var isCallDataSavingEnabled: Bool {
        get { return self.value(forKey: self.callDataSavingKey) }
        set { self.setValue(newValue, forKey: self.callDataSavingKey) }
    }

    /// Emits the current value, then again whenever a Developer switch flips. Main queue.
    public static var currencyRatesViewSignal: Signal<Bool, NoError> {
        return self.signal { self.isCurrencyRatesViewEnabled }
    }

    public static var adsPanelSignal: Signal<Bool, NoError> {
        return self.signal { self.isAdsPanelEnabled }
    }

    /// Re-emits the signal's latest value whenever the currency rates or the ads panel switch flips.
    /// Folded into the Settings data signal, so the Settings list adds or drops those rows live.
    public static func refreshing<T>(_ signal: Signal<T, NoError>) -> Signal<T, NoError> {
        return combineLatest(queue: Queue.mainQueue(), signal, self.currencyRatesViewSignal, self.adsPanelSignal)
        |> map { value, _, _ in
            return value
        }
    }

    private static func value(forKey key: String) -> Bool {
        return UserDefaults(suiteName: self.udSuite)?.object(forKey: key) as? Bool ?? false
    }

    private static func setValue(_ value: Bool, forKey key: String) {
        UserDefaults(suiteName: self.udSuite)?.set(value, forKey: key)
        NotificationCenter.default.post(name: .novagramDeveloperFlagsChanged, object: nil)
    }

    private static func signal(_ read: @escaping () -> Bool) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            subscriber.putNext(read())
            let observer = NotificationCenter.default.addObserver(forName: .novagramDeveloperFlagsChanged, object: nil, queue: .main) { _ in
                subscriber.putNext(read())
            }
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        |> distinctUntilChanged
    }
}

// MARK: - Roles

/// Who passed the developer login on this device. The login decides the role, and the role decides
/// which Developer switches show. A switch a role cannot see is turned off when that role logs in, so
/// it never stays on unseen.
public enum NovagramDeveloperRole: String {
    case developer
    case director

    /// The switches in the Developer section.
    public enum Switch {
        case removeAllAds
        case adEventsOff
        case currencyRatesView
        case adsPanel
        case callRecording
        case callDataSaving
    }

    private static let udSuite = "pro_messager"
    private static let roleKey = "novagram_developer_role"

    /// The developer sees every switch; the director only the ones they use.
    public func canUse(_ item: Switch) -> Bool {
        switch self {
        case .developer:
            return true
        case .director:
            switch item {
            case .adEventsOff, .adsPanel:
                return true
            case .removeAllAds, .currencyRatesView, .callRecording, .callDataSaving:
                return false
            }
        }
    }

    /// The role of the last login. A device opened before roles existed was opened by the developer.
    public static var current: NovagramDeveloperRole {
        let stored = UserDefaults(suiteName: self.udSuite)?.string(forKey: self.roleKey)
        return stored.flatMap(NovagramDeveloperRole.init(rawValue:)) ?? .developer
    }

    /// Stores the role that just logged in and turns off the switches it cannot see.
    static func didLogIn(_ role: NovagramDeveloperRole) {
        UserDefaults(suiteName: self.udSuite)?.set(role.rawValue, forKey: self.roleKey)
        if !role.canUse(.removeAllAds) && !NovagramShowAdsGate.isEnabled {
            NovagramShowAdsGate.setEnabled(true)
        }
        if !role.canUse(.adEventsOff) && NovagramDeveloperFlags.isAdEventsOff {
            NovagramDeveloperFlags.isAdEventsOff = false
        }
        if !role.canUse(.currencyRatesView) && NovagramDeveloperFlags.isCurrencyRatesViewEnabled {
            NovagramDeveloperFlags.isCurrencyRatesViewEnabled = false
        }
        if !role.canUse(.adsPanel) && NovagramDeveloperFlags.isAdsPanelEnabled {
            NovagramDeveloperFlags.isAdsPanelEnabled = false
        }
        if !role.canUse(.callRecording) && NovagramDeveloperFlags.isCallRecordingEnabled {
            NovagramDeveloperFlags.isCallRecordingEnabled = false
        }
        if !role.canUse(.callDataSaving) && NovagramDeveloperFlags.isCallDataSavingEnabled {
            NovagramDeveloperFlags.isCallDataSavingEnabled = false
        }
        NotificationCenter.default.post(name: .novagramDeveloperFlagsChanged, object: nil)
    }
}

// MARK: - Reveal

/// The Developer section is not in Novagram Settings by default. Holding the app version line at the
/// bottom of the Settings tab for `revealDuration` seconds toggles it: showing it asks for the
/// developer login first (`NovagramAdsAdminAuth`), hiding it needs nothing. Persisted across launches.
/// The login decides the role (`NovagramDeveloperRole`) and so which switches the section shows.
public enum NovagramDeveloperSection {
    /// How long the version line must be held.
    public static let revealDuration: TimeInterval = 20.0

    // The key predates the Developer section (it revealed the old Ads section); stored, never rename.
    private static let revealedKey = "fenix_ads_section_revealed"

    static var isRevealed: Bool {
        // A section revealed through the old, unprotected Easter-egg is hidden once.
        NovagramAdsAdminAuth.migrateLegacyRevealIfNeeded()
        return UserDefaults(suiteName: "pro_messager")?.object(forKey: self.revealedKey) as? Bool ?? false
    }

    private static func setRevealed(_ revealed: Bool) {
        UserDefaults(suiteName: "pro_messager")?.set(revealed, forKey: self.revealedKey)
    }

    /// The long-press action for the version line. Reads the state when it fires.
    public static func revealAction(context: AccountContext) -> () -> Void {
        return {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            if self.isRevealed {
                self.setRevealed(false)
                self.confirm(revealed: false, context: context, presentationData: presentationData, langCode: langCode)
                return
            }
            guard let host = self.topViewController(context: context) else {
                return
            }
            NovagramAdsAdminAuth.presentPrompt(from: host, langCode: langCode) { role in
                guard let role else {
                    return
                }
                NovagramDeveloperRole.didLogIn(role)
                self.setRevealed(true)
                self.confirm(revealed: true, context: context, presentationData: presentationData, langCode: langCode)
            }
        }
    }

    private static func confirm(revealed: Bool, context: AccountContext, presentationData: PresentationData, langCode: String) {
        HapticFeedback().success()
        let text: String
        if revealed {
            let path = "\(presentationData.strings.Settings_Title) → \(NovagramSettingsSectionStrings.settingsRowTitle(langCode: langCode))"
            text = NovagramDeveloperStrings.shownAlert(path: path, langCode: langCode)
        } else {
            text = NovagramDeveloperStrings.hiddenAlert(langCode: langCode)
        }
        let alert = textAlertController(
            context: context,
            title: nil,
            text: text,
            actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        )
        context.sharedContext.mainWindow?.present(alert, on: .root)
    }

    private static func topViewController(context: AccountContext) -> UIViewController? {
        guard var top = context.sharedContext.mainWindow?.hostView.containerView.window?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

// MARK: - Strings

enum NovagramDeveloperStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Dasturchi"
        case "ru": return "Для разработчиков"
        case "zh": return "开发者"
        default:   return "Developer"
        }
    }

    static func removeAdsTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Barcha reklamalarni o'chirish"
        case "ru": return "Убрать всю рекламу"
        case "zh": return "移除所有广告"
        default:   return "Remove all ads"
        }
    }

    static func removeAdsTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yoqilsa — bu qurilmada Novagram va Telegram reklamalari ko'rsatilmaydi"
        case "ru": return "Вкл — на этом устройстве нет рекламы ни Novagram, ни Telegram"
        case "zh": return "开启后，此设备上不显示 Novagram 和 Telegram 的任何广告"
        default:   return "On — no Novagram or Telegram ads on this device"
        }
    }

    static func adEventsOffTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Reklama hodisalarini yubormaslik"
        case "ru": return "Не отправлять события рекламы"
        case "zh": return "不发送广告事件"
        default:   return "Don't send ad events"
        }
    }

    static func adEventsOffTip(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Novagram va Telegram reklamalarining ko'rish, bosish va harakat hodisalari serverga yuborilmaydi, " +
                   "shuning uchun bir marta ko'rsatiladigan reklama test paytida qayta chiqaveradi. Faqat shu qurilmada."
        case "ru":
            return "Просмотры, клики и действия по рекламе Novagram и Telegram не отправляются, поэтому реклама " +
                   "с одним показом на пользователя продолжает показываться во время теста. Только на этом устройстве."
        case "zh":
            return "不发送 Novagram 和 Telegram 广告的浏览、点击和操作事件，因此每位用户只展示一次的广告在测试期间会继续展示。仅限此设备。"
        default:
            return "Views, clicks and actions of Novagram and Telegram ads are not sent, so an ad shown once per user " +
                   "keeps showing while you test. This device only."
        }
    }

    static func currencyRatesTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Valyuta kursini ko'rsatish"
        case "ru": return "Показывать курсы валют"
        case "zh": return "显示汇率"
        default:   return "Show currency rates"
        }
    }

    static func currencyRatesTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Markaziy bank kurslari oynasi"
        case "ru": return "Курсы Центрального банка"
        case "zh": return "中央银行汇率"
        default:   return "Central Bank rates view"
        }
    }

    static func adsPanelTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram reklama paneli"
        case "ru": return "Рекламная панель Novagram"
        case "zh": return "Novagram 广告面板"
        default:   return "Novagram ads panel"
        }
    }

    static func adsPanelTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram reklama panelini ko'rsatish"
        case "ru": return "Показывать рекламную панель Novagram"
        case "zh": return "显示 Novagram 广告面板"
        default:   return "Show the Novagram ads panel"
        }
    }

    static func callRecordingTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Qo'ng'iroqni yozib olish (beta)"
        case "ru": return "Запись звонков (бета)"
        case "zh": return "通话录音（测试版）"
        default:   return "Call recording (beta)"
        }
    }

    static func callDataSavingTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Qo'ng'iroqlarda kam trafik (beta)"
        case "ru": return "Экономия трафика в звонках (бета)"
        case "zh": return "通话时节省流量（测试版）"
        default:   return "Use less data for calls (beta)"
        }
    }

    static func footer(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Sinovdagi funksiyalar uchun yashirin tugmalar. Faqat shu qurilmada ishlaydi. " +
                   "Bo'limni yashirish uchun Sozlamalar pastidagi versiya qatorini 20 soniya bosib turing."
        case "ru":
            return "Скрытые переключатели для функций в тестировании. Действуют только на этом устройстве. " +
                   "Чтобы скрыть раздел, удерживайте строку версии внизу Настроек 20 секунд."
        case "zh":
            return "测试中功能的隐藏开关，仅对本设备生效。在设置底部按住版本号 20 秒可隐藏此部分。"
        default:
            return "Hidden switches for features in testing. They apply to this device only. " +
                   "To hide this section, hold the version line at the bottom of Settings for 20 seconds."
        }
    }

    static func shownAlert(path: String, langCode: String) -> String {
        switch langCode {
        case "uz": return "Dasturchi bo'limi ochildi: \(path)"
        case "ru": return "Раздел для разработчиков открыт: \(path)"
        case "zh": return "开发者设置已显示：\(path)"
        default:   return "Developer section is open: \(path)"
        }
    }

    static func hiddenAlert(langCode: String) -> String {
        switch langCode {
        case "uz": return "Dasturchi bo'limi yashirildi"
        case "ru": return "Раздел для разработчиков скрыт"
        case "zh": return "开发者设置已隐藏"
        default:   return "Developer section hidden"
        }
    }
}
