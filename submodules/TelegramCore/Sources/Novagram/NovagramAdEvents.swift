import Foundation

// Novagram Developer switch "Don't send ad events" (Novagram Settings → Developer).
//
// While it is on, Telegram's sponsored-message view and click reports are not sent, so an ad the
// server shows once per user keeps showing while a developer tests it. Per device, off by default.
// Ghost mode does not touch ads.
//
// TelegramCore cannot import the Novagram modules, so this reads the switch's key directly. The key
// is the one `NovagramDeveloperFlags.isAdEventsOff` writes (suite "pro_messager"); the Mac app uses
// the same key.
@inline(__always)
func novagramAdEventsOff() -> Bool {
    return UserDefaults(suiteName: "pro_messager")?.bool(forKey: "novagram_ads_events_off") == true
}
