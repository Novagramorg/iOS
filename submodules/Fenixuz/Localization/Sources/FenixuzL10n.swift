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
        if today { return "\(tasks_relative_today), \(time)" }
        if tomorrow { return "\(tasks_relative_tomorrow), \(time)" }
        if yesterday { return "\(tasks_relative_yesterday), \(time)" }
        return time
    }

    // MARK: - Settings → Fenixuz screen
    // Section headers, item titles, item subtitles, section footers, generic on/off labels.

    public var settings_title: String { "Novagram" } // Brand name — never translated

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
            en: "Up to 5 accounts can run live at once. Long-press any account to Activate (keep live) or Put to Sleep. The current account is always live. Sleeping accounts still receive notifications and wake up in 1–2 seconds when selected. This way even 100+ accounts won't slow your phone.",
            uz: "Bir vaqtda 5 tagacha account jonli ishlashi mumkin. Istalgan accountga uzoq bosib, uni Faollashtiring (jonli saqlanadi) yoki Uyquga qo'ying. Joriy account doim jonli bo'ladi. Uyqudagi accountlar bildirishnoma oladi va tanlaganda 1–2 soniyada jonlanadi. Shu tarzda 100+ account ham telefonni sekinlashtirmaydi.",
            ru: "До 5 аккаунтов могут работать одновременно. Зажмите любой аккаунт, чтобы Активировать (держать активным) или Усыпить. Текущий аккаунт всегда активен. Спящие аккаунты получают уведомления и просыпаются за 1–2 секунды при выборе. Так даже 100+ аккаунтов не замедлят телефон."
        )
    }

    // Tab-bar long-press account switcher
    public var accounts_switchTo: String {
        pick(en: "Switch account", uz: "Accountni almashtirish", ru: "Сменить аккаунт")
    }

    public var accounts_tabBarSwitchTitle: String {
        pick(en: "Switch to…", uz: "O'tish…", ru: "Перейти в…")
    }

    // MARK: - Tips / Imkoniyatlar (Feature guide)

    public var tips_screenTitle: String {
        pick(en: "Features", uz: "Imkoniyatlar", ru: "Возможности")
    }

    public var tips_closeButton: String {
        pick(en: "Got it!", uz: "Tushunarli!", ru: "Понятно!")
    }

    // Ghost mode
    public var tips_ghost_title: String {
        pick(en: "Ghost Mode", uz: "Ghost rejimi", ru: "Режим «Призрак»")
    }

    public var tips_ghost_body: String {
        pick(
            en: "Read messages without sending read receipts. Toggle the ghost icon at the top of your chat list — no one will know you were there.",
            uz: "Xabarlarni o'qildi belgisi yubormasdan o'qing. Chatlar ro'yxati tepasidagi ghost ikonkasini bosing — hech kim bilmaydi.",
            ru: "Читайте сообщения без отправки уведомлений о прочтении. Нажмите иконку призрака вверху списка чатов — никто не узнает."
        )
    }

    // Speech to text
    public var tips_stt_title: String {
        pick(en: "Voice → Text (STT)", uz: "Ovoz → Matn (STT)", ru: "Голос → Текст (STT)")
    }

    public var tips_stt_body: String {
        pick(
            en: "Tap the microphone button next to the text field to convert voice to text instantly. Enable it in Novagram → Voice → Text settings.",
            uz: "Matn maydonidagi mikrofon tugmasini bosib, ovozingizni darhol matnga aylantiring. Novagram → Ovoz → Matn sozlamalarida yoqing.",
            ru: "Нажмите кнопку микрофона рядом с полем ввода, чтобы мгновенно преобразовать голос в текст. Включите в настройках Novagram → Голос → Текст."
        )
    }

    // Multi-account
    public var tips_multiAccount_title: String {
        pick(en: "100+ Accounts", uz: "100+ Account", ru: "100+ Аккаунтов")
    }

    public var tips_multiAccount_body: String {
        pick(
            en: "Add as many Telegram accounts as you need. Only the active one runs — the rest sleep but still receive notifications. Switch in 1–2 seconds without slowing your phone.",
            uz: "Xohlagancha Telegram akkauntlarini qo'shing. Faqat tanlangan akkaunt ishlaydi — qolganlar uyquda, ammo bildirishnomalar kelaveradi. 1–2 soniyada almashing, telefon sekinlashmaydi.",
            ru: "Добавляйте любое количество аккаунтов Telegram. Активен только выбранный — остальные спят, но уведомления продолжают приходить. Переключение за 1–2 секунды без замедления телефона."
        )
    }

    // Edited message history
    public var tips_editedHistory_title: String {
        pick(en: "Edited Message History", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений")
    }

    public var tips_editedHistory_body: String {
        pick(
            en: "See every previous version of an edited message. Long-press any edited message and choose \"Editing history\" to view all changes.",
            uz: "Tahrirlangan xabarning barcha oldingi versiyalarini ko'ring. Tahrirlangan xabarga uzoq bosib, \"Tahrir tarixi\"ni tanlang.",
            ru: "Смотрите все предыдущие версии отредактированных сообщений. Зажмите любое отредактированное сообщение и выберите «История правок»."
        )
    }

    // Chat lock
    public var tips_chatLock_title: String {
        pick(en: "Chat Lock (PIN)", uz: "Chat qulfi (PIN)", ru: "Блокировка чатов (PIN)")
    }

    public var tips_chatLock_body: String {
        pick(
            en: "Protect individual chats with a PIN code. Only you can open locked chats — even if someone picks up your phone.",
            uz: "Alohida chatlarni PIN kod bilan himoyalang. Qulflangan chatni faqat siz ochishingiz mumkin.",
            ru: "Защитите отдельные чаты PIN-кодом. Заблокированный чат откроете только вы — даже если телефон окажется в чужих руках."
        )
    }

    // Auto-text
    public var tips_autoText_title: String {
        pick(en: "Auto-Text Suffix", uz: "Avto-matn qo'shimchasi", ru: "Авто-постфикс")
    }

    public var tips_autoText_body: String {
        pick(
            en: "Automatically add a custom text at the end of every outgoing message — a signature, hashtag, or anything you like. Configure in Novagram → Messages.",
            uz: "Har bir chiquvchi xabar oxiriga avtomatik matn qo'shing — imzo, hashtag yoki xohlagan narsa. Novagram → Xabarlar sozlamalarida o'rnatiladi.",
            ru: "Автоматически добавляйте произвольный текст в конец каждого исходящего сообщения — подпись, хэштег или что угодно. Настраивается в Novagram → Сообщения."
        )
    }

    // Translate
    public var tips_translate_title: String {
        pick(en: "Instant Translation", uz: "Tezkor tarjima", ru: "Мгновенный перевод")
    }

    public var tips_translate_body: String {
        pick(
            en: "Translate any message with one tap. Long-press a message and choose \"Translate\". Enable the button in Novagram → Messages settings.",
            uz: "Har qanday xabarni bir teginishda tarjima qiling. Xabarga uzoq bosib, \"Tarjima\" ni tanlang. Novagram → Xabarlar sozlamalarida yoqiladi.",
            ru: "Переводите любое сообщение одним нажатием. Зажмите сообщение и выберите «Перевести». Включается в настройках Novagram → Сообщения."
        )
    }

    // Fenixuz Settings hub
    public var tips_fenixHub_title: String {
        pick(en: "Novagram Settings Hub", uz: "Novagram sozlamalari markazi", ru: "Центр настроек Novagram")
    }

    public var tips_fenixHub_body: String {
        pick(
            en: "All Novagram features in one place. Open your Telegram Settings and tap the gold \"Novagram\" row to access Ghost mode, STT, auto-text, translate, chat lock, and more.",
            uz: "Barcha Novagram imkoniyatlari bir joyda. Telegram Sozlamalariga kirib, oltin rang \"Novagram\" qatoriga bosing — Ghost rejimi, STT, avto-matn, tarjima, chat qulfi va boshqalar.",
            ru: "Все функции Novagram в одном месте. Откройте Настройки Telegram и нажмите золотую строку «Novagram» — Ghost-режим, STT, авто-текст, перевод, блокировка чатов и многое другое."
        )
    }

    // MARK: - Edited message history toggle

    public var settings_chat_editedHistory_title: String {
        pick(en: "Edited message history", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений")
    }

    public var settings_chat_editedHistory_subtitle: String {
        pick(
            en: "Long-press any edited message to view all previous versions",
            uz: "Tahrirlangan xabarga uzoq bosib barcha oldingi versiyalarni ko'ring",
            ru: "Зажмите отредактированное сообщение, чтобы увидеть все предыдущие версии"
        )
    }

    // MARK: - Camera picker front/back labels

    public var cameraPicker_front: String {
        pick(en: "Front Camera", uz: "Old kamera", ru: "Передняя камера")
    }

    public var cameraPicker_back: String {
        pick(en: "Back Camera", uz: "Orqa kamera", ru: "Задняя камера")
    }

    // MARK: - Update check alert

    public var update_title: String {
        pick(en: "Update Available", uz: "Yangilanish mavjud", ru: "Доступно обновление")
    }

    public func update_message(version: String) -> String {
        pick(
            en: "A new version (\(version)) of Novagram is available on the App Store.",
            uz: "Novagram'ning yangi versiyasi (\(version)) App Store'da mavjud.",
            ru: "Новая версия Novagram (\(version)) доступна в App Store."
        )
    }

    public var update_actionUpdate: String {
        pick(en: "Update", uz: "Yangilash", ru: "Обновить")
    }

    public var update_actionLater: String {
        pick(en: "Later", uz: "Keyinroq", ru: "Позже")
    }

    // MARK: - Pinned accounts (no-sleep / activate)

    public var accounts_activate: String {
        pick(en: "Activate (No Sleep)", uz: "Faollashtirish (Uyqusiz)", ru: "Активировать (Без сна)")
    }

    public var accounts_putToSleep: String {
        pick(en: "Put to Sleep", uz: "Uyquga qo'yish", ru: "Перевести в сон")
    }

    public var accounts_maxLiveTitle: String {
        pick(en: "Maximum Reached", uz: "Chegara yetdi", ru: "Лимит достигнут")
    }

    public var accounts_maxLiveBody: String {
        pick(
            en: "Maximum 5 accounts can run at once — more will heat up and slow your phone. Put one to sleep first.",
            uz: "Bir vaqtda ko'pi bilan 5 ta account ishlashi mumkin — ko'proq telefon qizib, sekinlashadi. Avval birini uyquga qo'ying.",
            ru: "Одновременно может работать не более 5 аккаунтов — больше будет греть и замедлять телефон. Сначала усыпите один."
        )
    }

    public var accounts_maxLiveOk: String {
        pick(en: "OK", uz: "OK", ru: "OK")
    }

    // MARK: - QR-code login (phone entry screen)

    public var auth_qrLoginButton: String {
        pick(en: "Log in by QR code", uz: "QR kod orqali kirish", ru: "Войти по QR-коду")
    }

    // MARK: - About FenixPro (Settings → FenixPro → About)

    public var about_rowTitle: String {
        pick(en: "About NovagramPro", uz: "NovagramPro haqida", ru: "О NovagramPro")
    }

    public var about_screenTitle: String {
        pick(en: "About NovagramPro", uz: "NovagramPro haqida", ru: "О NovagramPro")
    }

    public var about_introHeader: String {
        pick(en: "WHAT IS NOVAGRAMPRO", uz: "NOVAGRAMPRO NIMA", ru: "ЧТО ТАКОЕ NOVAGRAMPRO")
    }

    public var about_introBody: String {
        pick(
            en: "NovagramPro is Telegram with a set of extra tools built on top. Everything below is included — no subscription, no paywall. Each feature can be turned on or off in NovagramPro settings.",
            uz: "NovagramPro — bu ustiga qo'shimcha vositalar qo'shilgan Telegram. Quyidagilarning barchasi bepul — obuna ham, to'lov ham yo'q. Har bir imkoniyatni NovagramPro sozlamalarida yoqish yoki o'chirish mumkin.",
            ru: "NovagramPro — это Telegram с набором дополнительных инструментов. Всё перечисленное ниже бесплатно — без подписки и без платного доступа. Каждую функцию можно включить или выключить в настройках NovagramPro."
        )
    }

    public var about_featuresHeader: String {
        pick(en: "FEATURES", uz: "IMKONIYATLAR", ru: "ВОЗМОЖНОСТИ")
    }

    // Ghost mode
    public var about_ghost_title: String {
        pick(en: "Ghost Mode", uz: "Ghost rejimi", ru: "Режим «Призрак»")
    }

    public var about_ghost_body: String {
        pick(
            en: "Read messages, view stories and ads, and stay online without sending a single \"seen\", \"typing\" or \"online\" signal.",
            uz: "Xabarlarni o'qing, storilar va reklamalarni ko'ring hamda \"ko'rildi\", \"yozyapti\" yoki \"onlayn\" signalini yubormasdan tarmoqda bo'ling.",
            ru: "Читайте сообщения, смотрите истории и рекламу и оставайтесь онлайн, не отправляя ни одного сигнала «просмотрено», «печатает» или «в сети»."
        )
    }

    // Multi-account
    public var about_multiAccount_title: String {
        pick(en: "Multi-Account (No Sleep)", uz: "Ko'p account (Uyqusiz)", ru: "Мультиаккаунт (без сна)")
    }

    public var about_multiAccount_body: String {
        pick(
            en: "Keep up to 5 accounts live in the background to receive notifications, while unlimited extra accounts sleep to save battery. Switch in 1–2 seconds.",
            uz: "Bildirishnomalarni olish uchun 5 tagacha accountni fonda jonli saqlang, qolgan cheksiz accountlar batareyani tejash uchun uyquda turadi. 1–2 soniyada almashing.",
            ru: "Держите до 5 аккаунтов активными в фоне для получения уведомлений, а неограниченное число остальных спит ради экономии заряда. Переключение за 1–2 секунды."
        )
    }

    // QR login
    public var about_qrLogin_title: String {
        pick(en: "QR Code Login", uz: "QR kod orqali kirish", ru: "Вход по QR-коду")
    }

    public var about_qrLogin_body: String {
        pick(
            en: "Sign in by scanning a QR code straight from the phone-number screen — no SMS code typing needed.",
            uz: "Telefon raqami ekranidan to'g'ridan-to'g'ri QR kodni skanerlab kiring — SMS kodni terish shart emas.",
            ru: "Входите, отсканировав QR-код прямо с экрана ввода номера — без набора кода из SMS."
        )
    }

    // Edited message history
    public var about_editedHistory_title: String {
        pick(en: "Edited Message History", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений")
    }

    public var about_editedHistory_body: String {
        pick(
            en: "See every previous version of an edited message. Long-press an edited message and choose \"Editing history\".",
            uz: "Tahrirlangan xabarning barcha oldingi versiyalarini ko'ring. Tahrirlangan xabarga uzoq bosib, \"Tahrir tarixi\"ni tanlang.",
            ru: "Смотрите все предыдущие версии отредактированного сообщения. Зажмите его и выберите «История правок»."
        )
    }

    // Speech to text
    public var about_stt_title: String {
        pick(en: "Voice → Text", uz: "Ovoz → Matn", ru: "Голос → Текст")
    }

    public var about_stt_body: String {
        pick(
            en: "Convert any voice message to text on your device with the microphone button next to the chat input.",
            uz: "Chat kirish maydoni yonidagi mikrofon tugmasi bilan har qanday ovozli xabarni qurilmangizda matnga aylantiring.",
            ru: "Преобразуйте любое голосовое сообщение в текст на устройстве с помощью кнопки микрофона рядом с полем ввода."
        )
    }

    // Chat lock
    public var about_chatLock_title: String {
        pick(en: "Chat Lock (PIN)", uz: "Chat qulfi (PIN)", ru: "Блокировка чатов (PIN)")
    }

    public var about_chatLock_body: String {
        pick(
            en: "Protect individual chats with a PIN code. Only you can open a locked chat, even if someone else picks up your phone.",
            uz: "Alohida chatlarni PIN kod bilan himoyalang. Qulflangan chatni faqat siz ochishingiz mumkin, telefon birovning qo'lida bo'lsa ham.",
            ru: "Защитите отдельные чаты PIN-кодом. Заблокированный чат откроете только вы, даже если телефон окажется у кого-то другого."
        )
    }

    // Auto-text & translate
    public var about_messaging_title: String {
        pick(en: "Auto-Text & Translation", uz: "Avto-matn va tarjima", ru: "Авто-текст и перевод")
    }

    public var about_messaging_body: String {
        pick(
            en: "Add a custom signature to every outgoing message automatically, and translate any incoming message with one tap.",
            uz: "Har bir chiquvchi xabar oxiriga avtomatik imzo qo'shing va istalgan kelgan xabarni bir teginishda tarjima qiling.",
            ru: "Автоматически добавляйте подпись в конец каждого исходящего сообщения и переводите любое входящее сообщение одним нажатием."
        )
    }

    public var about_footer: String {
        pick(
            en: "NovagramPro is built on top of Telegram. All your chats, contacts and data stay in your regular Telegram account.",
            uz: "NovagramPro Telegram asosida qurilgan. Barcha chatlaringiz, kontaktlaringiz va ma'lumotlaringiz oddiy Telegram accountingizda qoladi.",
            ru: "NovagramPro построен на основе Telegram. Все ваши чаты, контакты и данные остаются в вашем обычном аккаунте Telegram."
        )
    }
}
