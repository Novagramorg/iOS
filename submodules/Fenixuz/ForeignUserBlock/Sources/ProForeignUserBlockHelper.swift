import Foundation
import Postbox
import TelegramCore
import AccountContext

/// Telefon raqamidan davlat kodini (country calling code) ajratadi.
/// Misol: "998901234567" -> "998", "79001234567" -> "7", "14155551234" -> "1"
///
/// Bu funksiya eng uzun moslikni qidiradi (longest prefix match).
public func extractCountryCallingCode(from phoneNumber: String) -> String? {
    // Raqamni tozalash — faqat raqamlarni qoldirish
    let digits = phoneNumber.filter { $0.isNumber }
    guard !digits.isEmpty else { return nil }
    
    // Eng ko'p ishlatiladigan davlat kodlari (1-3 ta raqamli)
    // 3 raqamli kodlarni birinchi tekshiramiz (longest match first)
    let threeDigitCodes: Set<String> = [
        // O'zbekiston va CIS davlatlari
        "998", // UZ - O'zbekiston
        "992", // TJ - Tojikiston
        "993", // TM - Turkmaniston
        "994", // AZ - Ozarbayjon
        "995", // GE - Gruziya
        "996", // KG - Qirg'iziston
        "374", // AM - Armaniston
        "375", // BY - Belarus
        "380", // UA - Ukraina
        "373", // MD - Moldova
        "371", // LV - Latviya
        "370", // LT - Litva
        "372", // EE - Estoniya
        // Yaqin Sharq
        "971", // AE - BAA
        "966", // SA - Saudiya Arabistoni
        "965", // KW - Quvayt
        "968", // OM - Oman
        "974", // QA - Qatar
        "973", // BH - Bahrayn
        "964", // IQ - Iroq
        "963", // SY - Suriya
        "962", // JO - Iordaniya
        "961", // LB - Livan
        "967", // YE - Yaman
        // Osiyo
        "856", // LA - Laos
        "855", // KH - Kambodja
        "852", // HK - Gonkong
        "853", // MO - Makao
        "886", // TW - Tayvan
        "880", // BD - Bangladesh
        "977", // NP - Nepal
        "960", // MV - Maldiv
        "976", // MN - Mo'g'uliston
        "975", // BT - Butan
        "670", // TL - Sharqiy Timor
        "673", // BN - Bruney
        "959", // MM - Myanma
        // Afrika
        "234", // NG - Nigeriya
        "254", // KE - Keniya
        "255", // TZ - Tanzaniya
        "256", // UG - Uganda
        "251", // ET - Efiopiya
        "233", // GH - Gana
        "237", // CM - Kamerun
        "243", // CD - Kongo
        "221", // SN - Senegal
        "225", // CI - Kot-d'Ivuar
        "227", // NE - Niger
        "223", // ML - Mali
        "226", // BF - Burkina-Faso
        "229", // BJ - Benin
        "228", // TG - Togo
        "231", // LR - Liberiya
        "232", // SL - Serra-Leone
        "235", // TD - Chad
        "236", // CF - Markaziy Afrika
        "241", // GA - Gabon
        "242", // CG - Kongo Resp.
        "244", // AO - Angola
        "249", // SD - Sudan
        "252", // SO - Somali
        "253", // DJ - Jibuti
        "257", // BI - Burundi
        "258", // MZ - Mozambik
        "261", // MG - Madagaskar
        "263", // ZW - Zimbabve
        "260", // ZM - Zambiya
        "264", // NA - Namibiya
        "265", // MW - Malavi
        "266", // LS - Lesoto
        "267", // BW - Botsvana
        "268", // SZ - Esvatini
        "269", // KM - Komor orollari
        // Europa
        "351", // PT - Portugaliya
        "352", // LU - Lyuksemburg
        "353", // IE - Irlandiya
        "354", // IS - Islandiya
        "355", // AL - Albaniya
        "356", // MT - Malta
        "357", // CY - Kipr
        "358", // FI - Finlandiya
        "359", // BG - Bolgariya
        "381", // RS - Serbiya
        "382", // ME - Chernogoriya
        "383", // XK - Kosovo
        "385", // HR - Xorvatiya
        "386", // SI - Sloveniya
        "387", // BA - Bosniya
        "389", // MK - Shimoliy Makedoniya
        "420", // CZ - Chexiya
        "421", // SK - Slovakiya
        // Janubiy Amerika
        "591", // BO - Boliviya
        "592", // GY - Gayana
        "593", // EC - Ekvador
        "594", // GF - Frans. Gviana
        "595", // PY - Paragvay
        "596", // MQ - Martinika
        "597", // SR - Surinam
        "598", // UY - Urugvay
        // Boshqalar
        "212", // MA - Marokash
        "213", // DZ - Jazoir
        "216", // TN - Tunis
        "218", // LY - Liviya
        "220", // GM - Gambiya
        "222", // MR - Mavritaniya
        "238", // CV - Kabo-Verde
        "239", // ST - San-Tome
        "240", // GQ - Ekvatorial Gvineya
        "245", // GW - Gvineya-Bisau
        "246", // IO - Britaniya Hind okeani
        "247", // AC - Voznesenie oroli
        "248", // SC - Seyshel orollari
        "250", // RW - Ruanda
        "262", // RE - Reyunion
        "290", // SH - Muqaddas Yelena
        "291", // ER - Eritreya
        "297", // AW - Aruba
        "298", // FO - Farer orollari
        "299", // GL - Grenlandiya
    ]
    
    let twoDigitCodes: Set<String> = [
        "20", // EG - Misr
        "27", // ZA - Janubiy Afrika
        "30", // GR - Gretsiya
        "31", // NL - Niderlandiya
        "32", // BE - Belgiya
        "33", // FR - Frantsiya
        "34", // ES - Ispaniya
        "36", // HU - Vengriya
        "39", // IT - Italiya
        "40", // RO - Ruminiya
        "41", // CH - Shveytsariya
        "43", // AT - Avstriya
        "44", // GB - Buyuk Britaniya
        "45", // DK - Daniya
        "46", // SE - Shvetsiya
        "47", // NO - Norvegiya
        "48", // PL - Polsha
        "49", // DE - Germaniya
        "51", // PE - Peru
        "52", // MX - Meksika
        "53", // CU - Kuba
        "54", // AR - Argentina
        "55", // BR - Braziliya
        "56", // CL - Chili
        "57", // CO - Kolumbiya
        "58", // VE - Venesuela
        "60", // MY - Malayziya
        "61", // AU - Avstraliya
        "62", // ID - Indoneziya
        "63", // PH - Filippin
        "64", // NZ - Yangi Zelandiya
        "65", // SG - Singapur
        "66", // TH - Tailand
        "81", // JP - Yaponiya
        "82", // KR - Janubiy Koreya
        "84", // VN - Vyetnam
        "86", // CN - Xitoy
        "90", // TR - Turkiya
        "91", // IN - Hindiston
        "92", // PK - Pokiston
        "93", // AF - Afg'oniston
        "94", // LK - Shri Lanka
        "95", // MM - Myanma
        "98", // IR - Eron
    ]
    
    let singleDigitCodes: Set<String> = [
        "1", // US/CA - AQSH/Kanada
        "7", // RU/KZ - Rossiya/Qozog'iston
    ]
    
    // Avval 3 raqamli kodlarni tekshirish
    if digits.count >= 3 {
        let prefix3 = String(digits.prefix(3))
        if threeDigitCodes.contains(prefix3) {
            return prefix3
        }
    }
    
    // Keyin 2 raqamli kodlarni tekshirish
    if digits.count >= 2 {
        let prefix2 = String(digits.prefix(2))
        if twoDigitCodes.contains(prefix2) {
            return prefix2
        }
    }
    
    // Eng oxirida 1 raqamli kodlarni tekshirish
    if digits.count >= 1 {
        let prefix1 = String(digits.prefix(1))
        if singleDigitCodes.contains(prefix1) {
            return prefix1
        }
    }
    
    return nil
}

/// Ikki foydalanuvchining telefon raqamlari bir davlatga tegishli ekanligini tekshiradi.
/// Agar biror raqam yo'q bo'lsa yoki country code aniqlanmasa false qaytaradi (bloklash kerak).
public func arePhoneNumbersFromSameCountry(_ phone1: String?, _ phone2: String?) -> Bool {
    guard let p1 = phone1, let p2 = phone2 else {
        // Agar biror raqam yo'q bo'lsa — himoya sifatida bloklash
        return false
    }
    
    guard let code1 = extractCountryCallingCode(from: p1),
          let code2 = extractCountryCallingCode(from: p2) else {
        return false
    }
    
    return code1 == code2
}

/// Berilgan peer foreign user (boshqa davlat raqamli) ekanligini tekshiradi.
/// Faqat 1:1 shaxsiy chatlar uchun ishlaydi (guruh, kanal, bot uchun false qaytaradi).
public func isForeignUser(peer: Peer?, myPhone: String?) -> Bool {
    guard let user = peer as? TelegramUser else {
        // Guruh, kanal yoki bot emas — cheklov qo'llanilmaydi
        return false
    }
    
    // Bot bo'lsa cheklov qo'llanilmaydi
    if user.botInfo != nil {
        return false
    }
    
    // Saved Messages, Telegram Service va maxsus peer'lar uchun cheklov qo'llanilmaydi
    if user.id.isReplies || user.id.namespace != Namespaces.Peer.CloudUser {
        return false
    }
    
    // Telegram service accountlari (777000, 333000)
    let userId = user.id.id._internalGetInt64Value()
    if userId == 777000 || userId == 333000 {
        return false
    }
    
    // Faqat har ikkala telefon raqami mavjud bo'lgandagina tekshiramiz
    guard let myP = myPhone, !myP.isEmpty,
          let peerP = user.phone, !peerP.isEmpty else {
        // Telefon raqami ko'rinmasa — bloklash shart emas (privacy sozlamalari)
        return false
    }
    
    return !arePhoneNumbersFromSameCountry(myP, peerP)
}
