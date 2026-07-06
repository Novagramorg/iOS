import Foundation

// Decides whether the device is physically in Russia using only OFFLINE signals — there is no
// working Telegram connection to ask (that is the whole point: the user is blocked), so region
// and time zone are all we have. Either signal alone is enough: a Russian user with an English
// or US region setting still has a Russian time zone (auto-set from location), and vice versa.
enum FenixuzRussiaDetector {
    static func isLikelyInRussia() -> Bool {
        if let region = self.regionCode(), region.uppercased() == "RU" {
            return true
        }
        if self.russianTimeZones.contains(TimeZone.current.identifier) {
            return true
        }
        return false
    }

    // Device region. NSLocale.countryCode is used (not the iOS 16+ Locale.region API) because it
    // is available on every supported iOS version and is not deprecated, so it stays clean under
    // -warnings-as-errors.
    private static func regionCode() -> String? {
        return (Locale.current as NSLocale).object(forKey: .countryCode) as? String
    }

    // IANA time-zone identifiers physically inside the Russian Federation.
    private static let russianTimeZones: Set<String> = [
        "Europe/Kaliningrad",
        "Europe/Moscow",
        "Europe/Simferopol",
        "Europe/Kirov",
        "Europe/Volgograd",
        "Europe/Astrakhan",
        "Europe/Saratov",
        "Europe/Ulyanovsk",
        "Europe/Samara",
        "Asia/Yekaterinburg",
        "Asia/Omsk",
        "Asia/Novosibirsk",
        "Asia/Barnaul",
        "Asia/Tomsk",
        "Asia/Novokuznetsk",
        "Asia/Krasnoyarsk",
        "Asia/Irkutsk",
        "Asia/Chita",
        "Asia/Yakutsk",
        "Asia/Khandyga",
        "Asia/Vladivostok",
        "Asia/Ust-Nera",
        "Asia/Magadan",
        "Asia/Sakhalin",
        "Asia/Srednekolymsk",
        "Asia/Kamchatka",
        "Asia/Anadyr"
    ]
}
