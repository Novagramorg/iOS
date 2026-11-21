import Foundation

// MARK: - Model

/// "Ads tekshiruvi" (Developer section): one read-only run of the ad server's serve and active-banner
/// requests. NovagramSponsored owns the ads SDK and fills these types through `NovagramAdsCheck.provider`;
/// this module cannot import it (NovagramSponsored imports NovagramMessenger).
///
/// A failure keeps only its HTTP status class: an SDK error's text can carry a URL, so it never
/// reaches this model.
public enum NovagramAdsCheckFailure: Equatable, Sendable {
    case keyRejected(status: Int)
    case unavailable(status: Int)
    case rateLimited(status: Int)
    case http(status: Int)
    case network
    case badResponse
    case cancelled
    case unknown
}

public enum NovagramAdsCheckSlot: Equatable, Sendable {
    case search
    case bot
    case channelMessage
    case video
    case banners
}

public struct NovagramAdsCheckSlotResult: Equatable, Sendable {
    public var slot: NovagramAdsCheckSlot
    /// Requests made (6 search queries, 1 for the other slots).
    public var requests: Int
    /// Requests that returned an ad; for banners, the number of active banners.
    public var hits: Int
    /// The first ad's promoted peer ("@username" or its title).
    public var firstHit: String?
    /// Search only: the query of the first hit.
    public var firstQuery: String?
    public var failures: Int
    /// The first failure, when any request failed.
    public var failure: NovagramAdsCheckFailure?

    public init(slot: NovagramAdsCheckSlot, requests: Int, hits: Int, firstHit: String? = nil, firstQuery: String? = nil, failures: Int = 0, failure: NovagramAdsCheckFailure? = nil) {
        self.slot = slot
        self.requests = requests
        self.hits = hits
        self.firstHit = firstHit
        self.firstQuery = firstQuery
        self.failures = failures
        self.failure = failure
    }
}

public struct NovagramAdsCheckReport: Equatable, Sendable {
    public var production: Bool
    public var finishedAt: Date
    public var elapsedMs: Int
    public var slots: [NovagramAdsCheckSlotResult]

    public init(production: Bool, finishedAt: Date, elapsedMs: Int, slots: [NovagramAdsCheckSlotResult]) {
        self.production = production
        self.finishedAt = finishedAt
        self.elapsedMs = elapsedMs
        self.slots = slots
    }

    /// True when at least one request got an answer from the server (an ad or an empty answer).
    public var serverResponded: Bool {
        return self.slots.contains { $0.failures < $0.requests }
    }
}

public enum NovagramAdsCheck {
    /// Runs the check (`production` picks the environment, `lang` is the app language for targeting).
    /// Set by NovagramSponsored when its ads core starts; nil until then.
    public static var provider: ((_ production: Bool, _ lang: String) async -> NovagramAdsCheckReport)?
    /// The environment THIS build sends its ad requests to (true = production), set together with
    /// `provider`; nil until the ads core starts.
    public static var buildIsProduction: Bool?
}

// MARK: - Text

/// The copied text, one aligned line per slot.
func novagramAdsCheckText(_ report: NovagramAdsCheckReport, langCode: String) -> String {
    let nameWidth = 18
    var lines: [String] = [NovagramAdsCheckStrings.reportHeader(report, langCode: langCode)]
    if let buildIsProduction = NovagramAdsCheck.buildIsProduction {
        lines.append("build: " + NovagramAdsCheckStrings.environmentName(production: buildIsProduction))
    }
    for result in report.slots {
        let name = NovagramAdsCheckStrings.slotName(result.slot, langCode: langCode)
        let padded = name.count < nameWidth ? name + String(repeating: " ", count: nameWidth - name.count) : name + " "
        let mark: String
        if result.failure != nil && result.failures == result.requests {
            mark = "⚠️"
        } else {
            mark = result.hits > 0 ? "✅" : "❌"
        }
        lines.append(padded + mark + " " + novagramAdsCheckSummary(result, langCode: langCode))
    }
    let server = report.serverResponded ? "✅" : "❌"
    lines.append(NovagramAdsCheckStrings.responseLine(ms: report.elapsedMs, langCode: langCode) + " · server " + server)
    return lines.joined(separator: "\n")
}

/// "1/6  @username (query: novagram)", "0", "HTTP 403 — …" — the result part of a slot's line.
func novagramAdsCheckSummary(_ result: NovagramAdsCheckSlotResult, langCode: String) -> String {
    if let failure = result.failure, result.failures == result.requests {
        return NovagramAdsCheckStrings.failure(failure, langCode: langCode)
    }
    var text = novagramAdsCheckCount(result)
    if let detail = novagramAdsCheckDetail(result, langCode: langCode) {
        text += "  " + detail
    }
    return text
}

/// "1/6" for search, the plain count for the other slots.
func novagramAdsCheckCount(_ result: NovagramAdsCheckSlotResult) -> String {
    return result.slot == .search ? "\(result.hits)/\(result.requests)" : "\(result.hits)"
}

/// The first hit and, when only some requests failed, the failure — nil when there is neither.
func novagramAdsCheckDetail(_ result: NovagramAdsCheckSlotResult, langCode: String) -> String? {
    var parts: [String] = []
    if let firstHit = result.firstHit {
        if let query = result.firstQuery {
            parts.append("\(firstHit) (query: \(query))")
        } else {
            parts.append(firstHit)
        }
    }
    if let failure = result.failure, result.failures < result.requests {
        parts.append("⚠️ \(result.failures)× " + NovagramAdsCheckStrings.failure(failure, langCode: langCode))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}

// MARK: - Strings

enum NovagramAdsCheckStrings {
    static func title(langCode: String) -> String {
        switch langCode {
        case "uz": return "Ads tekshiruvi"
        case "ru": return "Проверка рекламы"
        case "zh": return "广告检查"
        default:   return "Ads check"
        }
    }

    static func rowTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Serverdan reklama keladimi"
        case "ru": return "Отдаёт ли сервер рекламу"
        case "zh": return "服务器是否返回广告"
        default:   return "Does the server serve ads"
        }
    }

    static func environmentHeader(langCode: String) -> String {
        switch langCode {
        case "uz": return "Muhit"
        case "ru": return "Окружение"
        case "zh": return "环境"
        default:   return "Environment"
        }
    }

    static func run(langCode: String) -> String {
        switch langCode {
        case "uz": return "Tekshirish"
        case "ru": return "Проверить"
        case "zh": return "检查"
        default:   return "Run check"
        }
    }

    static func running(langCode: String) -> String {
        switch langCode {
        case "uz": return "Tekshirilmoqda…"
        case "ru": return "Проверка…"
        case "zh": return "正在检查…"
        default:   return "Checking…"
        }
    }

    static func runFooter(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Faqat o'qish so'rovlari: SEARCH (6 ta so'rov), BOT, CHANNEL_MESSAGE, VIDEO va faol bannerlar. " +
                   "Ko'rish yoki boshqa reklama hodisasi yuborilmaydi, hech narsa hisoblanmaydi va to'lanmaydi. " +
                   "Har safar soxta foydalanuvchi ID ishlatiladi."
        case "ru":
            return "Только запросы на чтение: SEARCH (6 запросов), BOT, CHANNEL_MESSAGE, VIDEO и активные баннеры. " +
                   "Просмотры и другие события рекламы не отправляются, ничего не учитывается и не списывается. " +
                   "Каждый раз используется фиктивный ID пользователя."
        case "zh":
            return "仅读取请求：SEARCH（6 个查询）、BOT、CHANNEL_MESSAGE、VIDEO 和活动横幅。不发送浏览或其他广告事件，不计数也不扣费。每次使用虚拟用户 ID。"
        default:
            return "Read-only requests: SEARCH (6 queries), BOT, CHANNEL_MESSAGE, VIDEO and active banners. " +
                   "No view or other ad event is sent, so nothing is counted or charged. Each run uses a fake user id."
        }
    }

    static func copy(langCode: String) -> String {
        switch langCode {
        case "uz": return "Nusxalash"
        case "ru": return "Копировать"
        case "zh": return "复制"
        default:   return "Copy"
        }
    }

    static func copied(langCode: String) -> String {
        switch langCode {
        case "uz": return "Nusxalandi"
        case "ru": return "Скопировано"
        case "zh": return "已复制"
        default:   return "Copied"
        }
    }

    static func notReady(langCode: String) -> String {
        switch langCode {
        case "uz": return "Reklama moduli hali ishga tushmagan. Chatlar ro'yxatini ochib, qayta urinib ko'ring."
        case "ru": return "Модуль рекламы ещё не запущен. Откройте список чатов и попробуйте снова."
        case "zh": return "广告模块尚未启动。请打开聊天列表后重试。"
        default:   return "The ads module has not started yet. Open the chat list and try again."
        }
    }

    /// Which backend this build itself uses; development in a release build means ads vanish for users.
    static func buildEnvironment(production: Bool?, langCode: String) -> String {
        guard let production else {
            return self.notReady(langCode: langCode)
        }
        let name = self.environmentName(production: production)
        switch langCode {
        case "uz": return "Bu build reklamani \(name) serveridan so'raydi."
        case "ru": return "Эта сборка запрашивает рекламу у сервера \(name)."
        case "zh": return "此版本向 \(name) 服务器请求广告。"
        default:   return "This build requests ads from the \(name) server."
        }
    }

    static func environmentName(production: Bool) -> String {
        return production ? "production" : "development"
    }

    static func reportHeader(_ report: NovagramAdsCheckReport, langCode: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return "\(self.title(langCode: langCode)) — \(self.environmentName(production: report.production)) · \(formatter.string(from: report.finishedAt))"
    }

    static func slotName(_ slot: NovagramAdsCheckSlot, langCode: String) -> String {
        switch slot {
        case .search:         return "SEARCH"
        case .bot:            return "BOT"
        case .channelMessage: return "CHANNEL_MESSAGE"
        case .video:          return "VIDEO"
        case .banners:
            switch langCode {
            case "uz": return "Bannerlar"
            case "ru": return "Баннеры"
            case "zh": return "横幅"
            default:   return "Banners"
            }
        }
    }

    static func responseLine(ms: Int, langCode: String) -> String {
        switch langCode {
        case "uz": return "Javob: \(ms) ms"
        case "ru": return "Ответ: \(ms) мс"
        case "zh": return "响应：\(ms) ms"
        default:   return "Response: \(ms) ms"
        }
    }

    static func serverState(responded: Bool, langCode: String) -> String {
        switch langCode {
        case "uz": return responded ? "server javob berdi" : "server javob bermadi"
        case "ru": return responded ? "сервер ответил" : "сервер не ответил"
        case "zh": return responded ? "服务器已响应" : "服务器无响应"
        default:   return responded ? "server responded" : "server did not respond"
        }
    }

    static func failure(_ failure: NovagramAdsCheckFailure, langCode: String) -> String {
        switch failure {
        case let .keyRejected(status):
            switch langCode {
            case "uz": return "HTTP \(status) — kalit rad etildi"
            case "ru": return "HTTP \(status) — ключ отклонён"
            case "zh": return "HTTP \(status) — 密钥被拒绝"
            default:   return "HTTP \(status) — key rejected"
            }
        case let .unavailable(status):
            switch langCode {
            case "uz": return "HTTP \(status) — serving ishlamayapti"
            case "ru": return "HTTP \(status) — показ недоступен"
            case "zh": return "HTTP \(status) — 投放不可用"
            default:   return "HTTP \(status) — serving unavailable"
            }
        case let .rateLimited(status):
            switch langCode {
            case "uz": return "HTTP \(status) — so'rovlar juda ko'p"
            case "ru": return "HTTP \(status) — слишком много запросов"
            case "zh": return "HTTP \(status) — 请求过多"
            default:   return "HTTP \(status) — too many requests"
            }
        case let .http(status):
            return "HTTP \(status)"
        case .network:
            switch langCode {
            case "uz": return "tarmoq xatosi"
            case "ru": return "ошибка сети"
            case "zh": return "网络错误"
            default:   return "network error"
            }
        case .badResponse:
            switch langCode {
            case "uz": return "javob o'qilmadi"
            case "ru": return "ответ не прочитан"
            case "zh": return "无法读取响应"
            default:   return "unreadable response"
            }
        case .cancelled:
            switch langCode {
            case "uz": return "bekor qilindi"
            case "ru": return "отменено"
            case "zh": return "已取消"
            default:   return "cancelled"
            }
        case .unknown:
            switch langCode {
            case "uz": return "noma'lum xato"
            case "ru": return "неизвестная ошибка"
            case "zh": return "未知错误"
            default:   return "unknown error"
            }
        }
    }
}
