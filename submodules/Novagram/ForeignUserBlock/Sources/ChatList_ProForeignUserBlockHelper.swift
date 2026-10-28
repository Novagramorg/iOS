import Foundation

/// ChatListUI modul uchun country code extraction (TelegramUI modulidagi nusxasi).
/// Telefon raqamidan davlat kodini ajratadi: "998901234567" -> "998"
public func proExtractCountryCode(from digits: String) -> String? {
    guard !digits.isEmpty else { return nil }
    
    // 3 raqamli kodlar (eng ko'p ishlatiluvchi)
    let three: Set<String> = [
        "998","992","993","994","995","996","374","375","380","373","371","370","372",
        "971","966","965","968","974","973","964","963","962","961","967",
        "856","855","852","853","886","880","977","960","976","975","670","673","959",
        "234","254","255","256","251","233","237","243","221","225","227","223","226",
        "229","228","231","232","235","236","241","242","244","249","252","253","257",
        "258","261","263","260","264","265","266","267","268","269",
        "351","352","353","354","355","356","357","358","359",
        "381","382","383","385","386","387","389","420","421",
        "591","592","593","594","595","596","597","598",
        "212","213","216","218","220","222","238","239","240","245","246","247","248",
        "250","262","290","291","297","298","299",
    ]
    // 2 raqamli kodlar
    let two: Set<String> = [
        "20","27","30","31","32","33","34","36","39","40","41","43","44","45","46","47","48","49",
        "51","52","53","54","55","56","57","58",
        "60","61","62","63","64","65","66",
        "81","82","84","86","90","91","92","93","94","95","98",
    ]
    // 1 raqamli kodlar
    let one: Set<String> = ["1","7"]
    
    if digits.count >= 3 {
        let p3 = String(digits.prefix(3))
        if three.contains(p3) { return p3 }
    }
    if digits.count >= 2 {
        let p2 = String(digits.prefix(2))
        if two.contains(p2) { return p2 }
    }
    if digits.count >= 1 {
        let p1 = String(digits.prefix(1))
        if one.contains(p1) { return p1 }
    }
    return nil
}
