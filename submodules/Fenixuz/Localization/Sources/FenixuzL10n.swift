import Foundation
import TelegramPresentationData

// MARK: - Public API
//
// Usage:
//   FenixuzL10n(presentationData.strings).tab_tasks
//   FenixuzL10n.from(languageCode: "uz").settings_title
//
// Languages shipped: en (default), uz, ru. Anything else falls back to en.
//
// Why this lives in a Fenixuz submodule (not in Telegram/Telegram-iOS/*.lproj/Localizable.strings):
// adding our keys to Telegram's strings file would conflict on every `git pull upstream`.
// All Fenixuz strings live here so upstream merges stay clean.

public struct FenixuzL10n {
    private let langCode: String

    public init(_ strings: PresentationStrings) {
        self.langCode = strings.primaryComponent.languageCode
    }

    public init(languageCode: String) {
        self.langCode = languageCode
    }

    public static func from(languageCode: String) -> FenixuzL10n {
        FenixuzL10n(languageCode: languageCode)
    }

    private func pick(en: String, uz: String, ru: String) -> String {
        switch langCode {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }

    // MARK: - Tab + Tasks screens

    public var tab_tasks: String {
        pick(en: "Todos", uz: "Vazifalar", ru: "Задачи")
    }

    public var tasks_segment_scheduled: String {
        pick(en: "Scheduled", uz: "Rejalashtirilgan", ru: "Запланированные")
    }

    public var tasks_segment_todo: String {
        pick(en: "To-Do", uz: "Vazifalar", ru: "Задачи")
    }

    public var tasks_relative_today: String {
        pick(en: "Today", uz: "Bugun", ru: "Сегодня")
    }

    public var tasks_relative_tomorrow: String {
        pick(en: "Tomorrow", uz: "Ertaga", ru: "Завтра")
    }

    public var tasks_relative_yesterday: String {
        pick(en: "Yesterday", uz: "Kecha", ru: "Вчера")
    }

    public var tasks_scheduled_empty: String {
        pick(
            en: "📅\n\nNo scheduled messages\n\nTap the “+” button above\nto add your first plan.",
            uz: "📅\n\nRejalashtirilgan xabarlar yo'q\n\nYuqoridagi “+” tugmasini bosib\nbirinchi rejani qo'shing.",
            ru: "📅\n\nНет запланированных сообщений\n\nНажмите кнопку «+» выше,\nчтобы добавить первый план."
        )
    }

    public var tasks_scheduled_empty_short: String {
        pick(
            en: "No scheduled messages.\nTap “+” to add a new task.",
            uz: "Rejalashtirilgan xabarlar yo'q.\n\"+\" tugmasini bosib yangi task qo'shing.",
            ru: "Запланированных сообщений нет.\nНажмите «+», чтобы добавить новую задачу."
        )
    }

    public var tasks_folders_empty: String {
        pick(
            en: "🗂\n\nNo folders\n\nTap the “+” button above\nto create your first folder.",
            uz: "🗂\n\nPapkalar yo'q\n\nYuqoridagi “+” tugmasini bosib\nbirinchi papkangizni yarating.",
            ru: "🗂\n\nПапок нет\n\nНажмите кнопку «+» выше,\nчтобы создать первую папку."
        )
    }

    public var tasks_folders_empty_short: String {
        pick(
            en: "You don't have any folders yet. Add one.",
            uz: "Sizda hozircha papkalar yo'q. Yangi qo'shing.",
            ru: "У вас пока нет папок. Добавьте новую."
        )
    }

    public var tasks_items_empty: String {
        pick(
            en: "No tasks yet. Add a new one.",
            uz: "Sizda hozircha vazifalar yo'q. Yangi qo'shing.",
            ru: "Задач пока нет. Добавьте новую."
        )
    }

    public var tasks_newFolder_title: String {
        pick(en: "New Folder", uz: "Yangi papka", ru: "Новая папка")
    }

    public var tasks_newFolder_prompt: String {
        pick(en: "Enter folder name", uz: "Papka nomini kiriting", ru: "Введите название папки")
    }

    public var tasks_newTask_title: String {
        pick(en: "New Task", uz: "Yangi Vazifa", ru: "Новая задача")
    }

    public var tasks_newTask_prompt: String {
        pick(en: "Enter task name", uz: "Vazifa nomini kiriting", ru: "Введите название задачи")
    }

    public var tasks_action_openChat: String {
        pick(en: "Go to Chat", uz: "Chatga o'tish", ru: "Перейти в чат")
    }

    public var tasks_action_open: String {
        pick(en: "Open", uz: "Ochish", ru: "Открыть")
    }

    public var tasks_sendTo_title: String {
        pick(en: "Send to whom?", uz: "Kimga yuborish?", ru: "Кому отправить?")
    }

    public var tasks_listTitle: String {
        pick(en: "Task List", uz: "Vazifalar ro'yxati", ru: "Список задач")
    }

    // MARK: - Section headers (with formatted counts)

    public var tasks_section_scheduled_header: String {
        pick(en: "SCHEDULED", uz: "REJALASHTIRILGAN", ru: "ЗАПЛАНИРОВАНО")
    }

    public func tasks_section_scheduled_headerWithCount(_ count: Int) -> String {
        let pluralWord: String
        switch langCode {
        case "uz": pluralWord = "TA"
        case "ru": pluralWord = countRuWord(count, one: "ЗАДАЧА", few: "ЗАДАЧИ", many: "ЗАДАЧ")
        default:   pluralWord = count == 1 ? "TASK" : "TASKS"
        }
        return "\(tasks_section_scheduled_header) — \(count) \(pluralWord)"
    }

    public var tasks_section_folders_header: String {
        pick(en: "FOLDERS", uz: "PAPKALAR", ru: "ПАПКИ")
    }

    public func tasks_section_folders_headerWithCount(_ count: Int) -> String {
        let word: String
        switch langCode {
        case "uz": word = "TA"
        case "ru": word = countRuWord(count, one: "ПАПКА", few: "ПАПКИ", many: "ПАПОК")
        default:   word = count == 1 ? "FOLDER" : "FOLDERS"
        }
        return "\(tasks_section_folders_header) — \(count) \(word)"
    }

    public func tasks_section_folders_headerWithProgress(folders: Int, done: Int, total: Int) -> String {
        let suffix: String
        switch langCode {
        case "uz": suffix = "\(done)/\(total) BAJARILDI"
        case "ru": suffix = "\(done)/\(total) ВЫПОЛНЕНО"
        default:   suffix = "\(done)/\(total) DONE"
        }
        return "\(tasks_section_folders_headerWithCount(folders)) · \(suffix)"
    }

    // Russian plural helper: 1 → one, 2-4 → few, 0 / 5+ → many
    private func countRuWord(_ count: Int, one: String, few: String, many: String) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return few }
        return many
    }

    // MARK: - Date helpers

    /// Returns the appropriate `Locale` for date formatting in the user's language.
    public var dateLocale: Locale {
        switch langCode {
        case "uz": return Locale(identifier: "uz_UZ")
        case "ru": return Locale(identifier: "ru_RU")
        default:   return Locale(identifier: "en_US")
        }
    }

    public func tasks_relative_format(today: Bool, tomorrow: Bool, yesterday: Bool, time: String) -> String {
        if today    { return "\(tasks_relative_today), \(time)" }
        if tomorrow { return "\(tasks_relative_tomorrow), \(time)" }
        if yesterday { return "\(tasks_relative_yesterday), \(time)" }
        return time
    }

    // MARK: - Settings → Fenixuz screen
    // Section headers, item titles, item subtitles, section footers, generic on/off labels.

    public var settings_title: String { "Fenixuz" } // Brand name — never translated

    public var settings_state_enabled: String {
        pick(en: "On", uz: "Yoqilgan", ru: "Включено")
    }

    public var settings_state_disabled: String {
        pick(en: "Off", uz: "O'chirilgan", ru: "Отключено")
    }

    // Section headers (capitals)
    public var settings_section_interface: String {
        pick(en: "INTERFACE", uz: "INTERFEYS", ru: "ИНТЕРФЕЙС")
    }

    public var settings_section_chat: String {
        pick(en: "CHAT", uz: "CHAT", ru: "ЧАТ")
    }

    public var settings_section_messaging: String {
        pick(en: "MESSAGES", uz: "XABARLAR", ru: "СООБЩЕНИЯ")
    }

    public var settings_section_voice: String {
        pick(en: "VOICE → TEXT", uz: "OVOZ → MATN", ru: "ГОЛОС → ТЕКСТ")
    }

    public var settings_section_protection: String {
        pick(en: "PROTECTION", uz: "HIMOYA", ru: "ЗАЩИТА")
    }

    // Chat section extra items
    public var settings_chat_deletedMessages_title: String {
        pick(en: "Deleted messages", uz: "O'chirilgan xabarlar", ru: "Удалённые сообщения")
    }

    public var settings_chat_deletedMessages_subtitle: String {
        pick(
            en: "Show deleted messages with a 🗑 marker",
            uz: "O'chirilgan xabarlarni 🗑 belgi bilan ko'rsatish",
            ru: "Показывать удалённые сообщения с меткой 🗑"
        )
    }

    public var settings_chat_footer: String {
        pick(
            en: "Changes apply to all chats immediately.",
            uz: "O'zgarishlar barcha chatlarga darhol qo'llaniladi.",
            ru: "Изменения применяются ко всем чатам мгновенно."
        )
    }

    // Interface section
    public var settings_interface_hideFolders_title: String {
        pick(en: "Hide folders", uz: "Jildlarni yashirish", ru: "Скрыть папки")
    }

    public var settings_interface_hideFolders_subtitle: String {
        pick(
            en: "Temporarily hide folders at the top of the chat list",
            uz: "Chatlar ro'yxati tepasidagi jildlarni vaqtinchalik berkitish",
            ru: "Временно скрыть папки в верхней части списка чатов"
        )
    }

    public var settings_interface_stories_title: String {
        pick(en: "Stories panel", uz: "Hikoyalar paneli", ru: "Панель историй")
    }

    public var settings_interface_stories_subtitle: String {
        pick(
            en: "Show stories at the top of the chat list",
            uz: "Chatlar ro'yxati tepasida hikoyalarni ko'rsatish",
            ru: "Показывать истории над списком чатов"
        )
    }

    public var settings_interface_mutualSymbol_title: String {
        pick(en: "Mutual contact badge", uz: "Mutual kontakt belgisi", ru: "Значок взаимного контакта")
    }

    public var settings_interface_mutualSymbol_subtitle: String {
        pick(
            en: "Show the 🤝 badge in the contacts list",
            uz: "Kontaktlar ro'yxatida 🤝 belgisini ko'rsatish",
            ru: "Показывать значок 🤝 в списке контактов"
        )
    }

    public var settings_interface_footer: String {
        pick(
            en: "Affects only this device.",
            uz: "Faqat sizning qurilmangizga ta'sir qiladi.",
            ru: "Влияет только на это устройство."
        )
    }

    // Chat tools section
    public var settings_chat_firstMessage_title: String {
        pick(en: "Jump to first message", uz: "Birinchi xabarga o'tish", ru: "К первому сообщению")
    }

    public var settings_chat_firstMessage_subtitle: String {
        pick(
            en: "Add a “View First Message” entry to the profile menu",
            uz: "Profil menyusida \"View First Message\" tugmasini qo'shish",
            ru: "Добавить пункт «Перейти к первому сообщению» в меню профиля"
        )
    }

    public var settings_chat_ghost_title: String {
        pick(en: "Ghost mode button", uz: "Ghost rejimi tugmasi", ru: "Кнопка режима «Призрак»")
    }

    public var settings_chat_ghost_subtitle: String {
        pick(
            en: "Quick Ghost-mode toggle at the top of the chat list",
            uz: "Chatlar ro'yxati tepasida tezkor Ghost rejimi tugmasi",
            ru: "Быстрое переключение «Призрак» над списком чатов"
        )
    }

    public var settings_chat_camera_title: String {
        pick(en: "Camera picker", uz: "Kamerani tanlash", ru: "Выбор камеры")
    }

    public var settings_chat_camera_subtitle: String {
        pick(
            en: "Long-press the video-message button to switch front/back camera",
            uz: "Video xabar tugmasini uzun bosib old/orqa kamerani tanlash",
            ru: "Долгое нажатие на кнопку видео-сообщения переключает камеру"
        )
    }

    // Messaging section
    public var settings_messaging_textStyle_title: String {
        pick(en: "Text style", uz: "Yozuv uslubi", ru: "Стиль текста")
    }

    public var settings_messaging_autoText_title: String {
        pick(en: "Auto-text suffix", uz: "Avto-matn qo'shimchasi", ru: "Авто-постфикс")
    }

    public var settings_messaging_autoTranslate_title: String {
        pick(en: "Auto-translate", uz: "Avto-tarjima", ru: "Авто-перевод")
    }

    public var settings_messaging_translateToggle_title: String {
        pick(en: "Translate button", uz: "Tarjima tugmasi", ru: "Кнопка перевода")
    }

    public var settings_messaging_translateToggle_subtitle: String {
        pick(
            en: "Show “Translate” in the message context menu",
            uz: "Xabar context menyusida \"Translate\" ko'rsatilsin",
            ru: "Показывать «Перевести» в контекстном меню сообщения"
        )
    }

    public var settings_messaging_translateLanguage_title: String {
        pick(en: "Translation language", uz: "Tarjima tili", ru: "Язык перевода")
    }

    public var settings_messaging_footer: String {
        pick(
            en: "Controls the appearance and translation of outgoing messages.",
            uz: "Yuboriladigan xabarlarning ko'rinishi va tarjimasini boshqaradi.",
            ru: "Управляет видом и переводом исходящих сообщений."
        )
    }

    // Voice section
    public var settings_voice_stt_title: String {
        pick(en: "Voice to text", uz: "Ovozni matnga o'girish", ru: "Голос в текст")
    }

    public var settings_voice_stt_subtitle: String {
        pick(
            en: "Show the STT shortcut near the microphone",
            uz: "Mikrofon yonida tezkor STT tugmasini ko'rsatish",
            ru: "Кнопка распознавания рядом с микрофоном"
        )
    }

    public var settings_voice_sttLang_title: String {
        pick(en: "Recognition language", uz: "Tanish tili", ru: "Язык распознавания")
    }

    // Protection section
    public var settings_protection_foreign_title: String {
        pick(en: "Block foreign numbers", uz: "Xorijiy raqamlarni bloklash", ru: "Блокировать иностранные номера")
    }

    public var settings_protection_foreign_subtitle: String {
        pick(
            en: "Automatically block messages from numbers in other countries",
            uz: "Boshqa davlat raqamlaridan kelgan xabarlarni avtomatik bloklash",
            ru: "Автоматически блокировать сообщения с зарубежных номеров"
        )
    }

    public var settings_protection_apk_title: String {
        pick(en: "Block APK files", uz: "APK fayllarni bloklash", ru: "Блокировать APK-файлы")
    }

    public var settings_protection_apk_subtitle: String {
        pick(
            en: "Hide .apk files in chats (Android packages)",
            uz: "Chatlarda .apk fayllarni yashirish (Android dasturlari)",
            ru: "Скрывать .apk-файлы в чатах (Android-пакеты)"
        )
    }

    public var settings_protection_footer: String {
        pick(
            en: "Protection from spam and harmful content.",
            uz: "Spam va zararli kontentdan himoya.",
            ru: "Защита от спама и вредоносного контента."
        )
    }

    // MARK: - Text style picker

    public func textStyle_displayName(_ key: String) -> String {
        switch key {
        case "bold":
            return pick(en: "Bold", uz: "Qalin (Bold)", ru: "Жирный (Bold)")
        case "italic":
            return pick(en: "Italic", uz: "Kiyshiq (Italic)", ru: "Курсив (Italic)")
        case "monospace":
            return pick(en: "Monospace (Code)", uz: "Monospace (Kod)", ru: "Моноширинный (Код)")
        case "strikethrough":
            return pick(en: "Strikethrough", uz: "Chizilgan (Strikethrough)", ru: "Зачёркнутый (Strikethrough)")
        case "underline":
            return pick(en: "Underline", uz: "Tagiga chizilgan (Underline)", ru: "Подчёркнутый (Underline)")
        case "spoiler":
            return "Spoiler" // Same word in all locales
        default:
            return pick(en: "Plain (None)", uz: "Uslubsiz (Oddiy)", ru: "Без стиля (Обычный)")
        }
    }

    public func textStyle_example(_ key: String) -> String {
        switch key {
        case "bold":
            return pick(
                en: "Example: Hi, this message will be sent in Bold style",
                uz: "Misol: Salom, bu xabar qalin (Bold) ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено жирным (Bold)"
            )
        case "italic":
            return pick(
                en: "Example: Hi, this message will be sent in Italic style",
                uz: "Misol: Salom, bu xabar kiyshiq (Italic) ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено курсивом (Italic)"
            )
        case "monospace":
            return pick(
                en: "Example: Hi, this message will be sent in monospace (code) style",
                uz: "Misol: Salom, bu xabar monospace (kod) ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено моноширинным (код)"
            )
        case "strikethrough":
            return pick(
                en: "Example: Hi, this message will be sent strikethrough",
                uz: "Misol: Salom, bu xabar chizilgan ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено зачёркнутым"
            )
        case "underline":
            return pick(
                en: "Example: Hi, this message will be sent underlined",
                uz: "Misol: Salom, bu xabar tagiga chizilgan ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено подчёркнутым"
            )
        case "spoiler":
            return pick(
                en: "Example: Hi, this message will be sent as a spoiler (tap to reveal)",
                uz: "Misol: Salom, bu xabar spoiler ko'rinishda yuboriladi (bosib ko'rish kerak)",
                ru: "Пример: Привет, это сообщение будет отправлено как спойлер (нажмите, чтобы открыть)"
            )
        default:
            return pick(
                en: "No style selected. Messages will be sent as plain text",
                uz: "Uslub tanlanmagan. Xabarlar oddiy matn sifatida yuboriladi",
                ru: "Стиль не выбран. Сообщения будут отправлены обычным текстом"
            )
        }
    }

    // MARK: - App Store IAP compliance (Apple guideline 3.1.1)

    public var iap_block_title: String {
        pick(
            en: "Telegram Premium",
            uz: "Telegram Premium",
            ru: "Telegram Premium"
        )
    }

    public var iap_block_message: String {
        pick(
            en: "Premium subscriptions are not sold in this app. To subscribe to Telegram Premium, please install the official Telegram app from the App Store and subscribe there.",
            uz: "Premium obuna bu ilovada sotilmaydi. Telegram Premium'ga obuna bo'lish uchun App Store'dan rasmiy Telegram ilovasini o'rnating va obunani o'sha yerda amalga oshiring.",
            ru: "Premium-подписка в этом приложении не продаётся. Чтобы подписаться на Telegram Premium, установите официальное приложение Telegram из App Store и оформите подписку там."
        )
    }

    public var iap_block_open_app_store: String {
        pick(
            en: "Open App Store",
            uz: "App Store'da ochish",
            ru: "Открыть App Store"
        )
    }

    public var iap_block_cancel: String {
        pick(
            en: "Cancel",
            uz: "Bekor qilish",
            ru: "Отмена"
        )
    }

    // MARK: - All Accounts (multi-account working-set)

    public var accounts_allAccounts: String {
        pick(en: "All Accounts", uz: "Barcha accountlar", ru: "Все аккаунты")
    }

    public var accounts_sectionHeader: String {
        pick(en: "ACCOUNTS", uz: "ACCOUNTLAR", ru: "АККАУНТЫ")
    }

    public func accounts_summary(total: Int, active: Int) -> String {
        pick(
            en: "TOTAL: \(total) accounts · \(active) active",
            uz: "JAMI: \(total) ta account · \(active) ta faol",
            ru: "ВСЕГО: \(total) аккаунтов · \(active) активных"
        )
    }

    public var accounts_current: String {
        pick(en: "Current", uz: "Joriy", ru: "Текущий")
    }

    public var accounts_active: String {
        pick(en: "Active", uz: "Faol", ru: "Активный")
    }

    public var accounts_sleeping: String {
        pick(en: "sleeping", uz: "uyquda", ru: "спит")
    }

    public var accounts_accountFallback: String {
        pick(en: "Account", uz: "Account", ru: "Аккаунт")
    }

    public var accounts_footer: String {
        pick(
            en: "For fast performance, only the selected account stays live. The others sleep — but their notifications keep arriving. Select any account and it wakes up in a few seconds. This way even 100+ accounts won't slow your phone down.",
            uz: "Tezkor ishlash uchun faqat tanlangan account jonli turadi. Qolganlari uyquda bo'ladi — ammo ularga ham bildirishnomalar to'xtovsiz kelaveradi. Istalgan accountni tanlasangiz, bir necha soniyada jonlanadi. Shu tarzda 100+ account ham telefonni sekinlashtirmaydi.",
            ru: "Для быстрой работы активен только выбранный аккаунт. Остальные спят — но уведомления для них продолжают приходить. Выберите любой аккаунт — он проснётся за несколько секунд. Так даже 100+ аккаунтов не замедлят телефон."
        )
    }
}
