import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences

/// Novagram Settings → Developer → "Use less data for calls" (HOOKS.md, "Call weak signal and data saver").
///
/// It drives Telegram's own setting (Data and Storage → Use less data for calls), not a second mechanism:
/// on sets it to "Always", off back to "Default". The switch shows the live setting, so a change made in
/// Data and Storage shows here too. A call reads the setting when it is created, so a change applies
/// from the next call.
enum NovagramCallDataSaving {
    /// Same key as the Mac app (`pro_messager` suite). Persisted: never rename it.
    static let key = "novagram_call_data_saving"
    private static let suiteName = "pro_messager"

    /// True while Telegram's call data saving setting is "Always".
    static func isOnSignal(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
        return accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings])
        |> map { sharedData -> Bool in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? VoiceCallSettings.defaultSettings
            return settings.dataSaving == .always
        }
        |> distinctUntilChanged
    }

    /// Turns our key off without touching Telegram's setting (a role that cannot see the switch logged in).
    static func clearKey() {
        UserDefaults(suiteName: suiteName)?.set(false, forKey: key)
    }

    static func set(_ isOn: Bool, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        UserDefaults(suiteName: suiteName)?.set(isOn, forKey: key)
        _ = updateVoiceCallSettingsSettingsInteractively(accountManager: accountManager, { current in
            var updated = current
            updated.dataSaving = isOn ? .always : .default
            return updated
        }).start()
    }
}
