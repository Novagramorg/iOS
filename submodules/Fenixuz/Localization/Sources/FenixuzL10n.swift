import Foundation
import TelegramPresentationData

// MARK: - Public API
//
// Usage:
//   FenixuzL10n(presentationData.strings).tab_tasks
//   FenixuzL10n.from(languageCode: "uz").settings_title
//
// Languages shipped: en (default), uz, ru, zh (Simplified Chinese). Anything else falls back to en.
//
// Why this lives in a Fenixuz submodule (not in Telegram/Telegram-iOS/*.lproj/Localizable.strings):
// adding our keys to Telegram's strings file would conflict on every `git pull upstream`.
// All Fenixuz strings live here so upstream merges stay clean.

public struct FenixuzL10n {
    private let langCode: String

    public init(_ strings: PresentationStrings) {
        self.langCode = FenixuzL10n.languageKey(for: strings)
    }

    public init(languageCode: String) {
        self.langCode = FenixuzL10n.languageKey(forCode: languageCode)
    }

    public static func from(languageCode: String) -> FenixuzL10n {
        FenixuzL10n(languageCode: languageCode)
    }

    /// The language our own strings should use for the app's current Telegram language:
    /// "zh" for any Chinese language pack, otherwise the pack's own code ("en", "uz", "ru", ...).
    ///
    /// Telegram has no official Chinese localization, so Chinese users install community packs
    /// whose codes are arbitrary ("zhcncc", "classic-zh-cn", "taiwan", ...). The pack's base
    /// language ("zh-hans-raw") or its plural rules ("zh") still say Chinese, so check those too.
    public static func languageKey(for strings: PresentationStrings) -> String {
        let primaryCode = strings.primaryComponent.languageCode
        if isChinese(code: primaryCode) {
            return "zh"
        }
        if let baseCode = strings.secondaryComponent?.languageCode, isChinese(code: baseCode) {
            return "zh"
        }
        if let pluralCode = strings.primaryComponent.pluralizationRulesCode, isChinese(code: pluralCode) {
            return "zh"
        }
        return primaryCode
    }

    /// Same as `languageKey(for:)` when only a bare code is known (a Telegram pack code,
    /// `baseLanguageCode`, or the device language).
    public static func languageKey(forCode code: String) -> String {
        return isChinese(code: code) ? "zh" : code
    }

    private static func isChinese(code: String) -> Bool {
        let code = code.lowercased()
        return code.hasPrefix("zh") || code.contains("-zh") || code.contains("_zh")
    }

    private func pick(en: String, uz: String, ru: String, zh: String) -> String {
        switch langCode {
        case "uz": return uz
        case "ru": return ru
        case "zh": return zh
        default:   return en
        }
    }

    // MARK: - Tab + Tasks screens

    public var tab_tasks: String {
        pick(en: "Todos", uz: "Vazifalar", ru: "Задачи", zh: "待办")
    }

    public var tasks_segment_scheduled: String {
        pick(en: "Scheduled", uz: "Rejalashtirilgan", ru: "Запланированные", zh: "定时消息")
    }

    public var tasks_segment_todo: String {
        pick(en: "To-Do", uz: "Vazifalar", ru: "Задачи", zh: "待办事项")
    }

    public var tasks_relative_today: String {
        pick(en: "Today", uz: "Bugun", ru: "Сегодня", zh: "今天")
    }

    public var tasks_relative_tomorrow: String {
        pick(en: "Tomorrow", uz: "Ertaga", ru: "Завтра", zh: "明天")
    }

    public var tasks_relative_yesterday: String {
        pick(en: "Yesterday", uz: "Kecha", ru: "Вчера", zh: "昨天")
    }

    public var tasks_scheduled_empty: String {
        pick(
            en: "📅\n\nNo scheduled messages\n\nTap the “+” button above\nto add your first plan.",
            uz: "📅\n\nRejalashtirilgan xabarlar yo'q\n\nYuqoridagi “+” tugmasini bosib\nbirinchi rejani qo'shing.",
            ru: "📅\n\nНет запланированных сообщений\n\nНажмите кнопку «+» выше,\nчтобы добавить первый план.",
            zh: "📅\n\n暂无定时消息\n\n点击上方的“+”按钮\n添加你的第一个计划。"
        )
    }

    public var tasks_scheduled_empty_short: String {
        pick(
            en: "No scheduled messages.\nTap “+” to add a new task.",
            uz: "Rejalashtirilgan xabarlar yo'q.\n\"+\" tugmasini bosib yangi task qo'shing.",
            ru: "Запланированных сообщений нет.\nНажмите «+», чтобы добавить новую задачу.",
            zh: "暂无定时消息。\n点击“+”添加新任务。"
        )
    }

    public var tasks_folders_empty: String {
        pick(
            en: "🗂\n\nNo folders\n\nTap the “+” button above\nto create your first folder.",
            uz: "🗂\n\nPapkalar yo'q\n\nYuqoridagi “+” tugmasini bosib\nbirinchi papkangizni yarating.",
            ru: "🗂\n\nПапок нет\n\nНажмите кнопку «+» выше,\nчтобы создать первую папку.",
            zh: "🗂\n\n暂无文件夹\n\n点击上方的“+”按钮\n创建你的第一个文件夹。"
        )
    }

    public var tasks_folders_empty_short: String {
        pick(
            en: "You don't have any folders yet. Add one.",
            uz: "Sizda hozircha papkalar yo'q. Yangi qo'shing.",
            ru: "У вас пока нет папок. Добавьте новую.",
            zh: "你还没有文件夹，添加一个吧。"
        )
    }

    public var tasks_items_empty: String {
        pick(
            en: "No tasks yet. Add a new one.",
            uz: "Sizda hozircha vazifalar yo'q. Yangi qo'shing.",
            ru: "Задач пока нет. Добавьте новую.",
            zh: "还没有任务，添加一个吧。"
        )
    }

    public var tasks_newFolder_title: String {
        pick(en: "New Folder", uz: "Yangi papka", ru: "Новая папка", zh: "新建文件夹")
    }

    public var tasks_newFolder_prompt: String {
        pick(en: "Enter folder name", uz: "Papka nomini kiriting", ru: "Введите название папки", zh: "输入文件夹名称")
    }

    public var tasks_newTask_title: String {
        pick(en: "New Task", uz: "Yangi Vazifa", ru: "Новая задача", zh: "新建任务")
    }

    public var tasks_newTask_prompt: String {
        pick(en: "Enter task name", uz: "Vazifa nomini kiriting", ru: "Введите название задачи", zh: "输入任务名称")
    }

    public var tasks_action_openChat: String {
        pick(en: "Go to Chat", uz: "Chatga o'tish", ru: "Перейти в чат", zh: "前往聊天")
    }

    public var tasks_action_open: String {
        pick(en: "Open", uz: "Ochish", ru: "Открыть", zh: "打开")
    }

    public var tasks_sendTo_title: String {
        pick(en: "Send to whom?", uz: "Kimga yuborish?", ru: "Кому отправить?", zh: "发送给谁？")
    }

    public var tasks_listTitle: String {
        pick(en: "Task List", uz: "Vazifalar ro'yxati", ru: "Список задач", zh: "任务列表")
    }

    // MARK: - Section headers (with formatted counts)

    public var tasks_section_scheduled_header: String {
        pick(en: "SCHEDULED", uz: "REJALASHTIRILGAN", ru: "ЗАПЛАНИРОВАНО", zh: "定时消息")
    }

    public func tasks_section_scheduled_headerWithCount(_ count: Int) -> String {
        let pluralWord: String
        switch langCode {
        case "uz": pluralWord = "TA"
        case "ru": pluralWord = countRuWord(count, one: "ЗАДАЧА", few: "ЗАДАЧИ", many: "ЗАДАЧ")
        case "zh": pluralWord = "条"
        default:   pluralWord = count == 1 ? "TASK" : "TASKS"
        }
        return "\(tasks_section_scheduled_header) — \(count) \(pluralWord)"
    }

    public var tasks_section_folders_header: String {
        pick(en: "FOLDERS", uz: "PAPKALAR", ru: "ПАПКИ", zh: "文件夹")
    }

    public func tasks_section_folders_headerWithCount(_ count: Int) -> String {
        let word: String
        switch langCode {
        case "uz": word = "TA"
        case "ru": word = countRuWord(count, one: "ПАПКА", few: "ПАПКИ", many: "ПАПОК")
        case "zh": word = "个"
        default:   word = count == 1 ? "FOLDER" : "FOLDERS"
        }
        return "\(tasks_section_folders_header) — \(count) \(word)"
    }

    public func tasks_section_folders_headerWithProgress(folders: Int, done: Int, total: Int) -> String {
        let suffix: String
        switch langCode {
        case "uz": suffix = "\(done)/\(total) BAJARILDI"
        case "ru": suffix = "\(done)/\(total) ВЫПОЛНЕНО"
        case "zh": suffix = "已完成 \(done)/\(total)"
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
        case "zh": return Locale(identifier: "zh_CN")
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
        pick(en: "On", uz: "Yoqilgan", ru: "Включено", zh: "开")
    }

    public var settings_state_disabled: String {
        pick(en: "Off", uz: "O'chirilgan", ru: "Отключено", zh: "关")
    }

    // Section headers (capitals)
    public var settings_section_interface: String {
        pick(en: "INTERFACE", uz: "INTERFEYS", ru: "ИНТЕРФЕЙС", zh: "界面")
    }

    public var settings_section_chat: String {
        pick(en: "CHAT", uz: "CHAT", ru: "ЧАТ", zh: "聊天")
    }

    public var settings_section_messaging: String {
        pick(en: "MESSAGES", uz: "XABARLAR", ru: "СООБЩЕНИЯ", zh: "消息")
    }

    public var settings_section_voice: String {
        pick(en: "VOICE → TEXT", uz: "OVOZ → MATN", ru: "ГОЛОС → ТЕКСТ", zh: "语音 → 文字")
    }

    public var settings_section_protection: String {
        pick(en: "PROTECTION", uz: "HIMOYA", ru: "ЗАЩИТА", zh: "安全防护")
    }

    // Chat section extra items
    public var settings_chat_deletedMessages_title: String {
        pick(en: "Deleted messages", uz: "O'chirilgan xabarlar", ru: "Удалённые сообщения", zh: "已删除的消息")
    }

    public var settings_chat_deletedMessages_subtitle: String {
        pick(
            en: "Show deleted messages with a 🗑 marker",
            uz: "O'chirilgan xabarlarni 🗑 belgi bilan ko'rsatish",
            ru: "Показывать удалённые сообщения с меткой 🗑",
            zh: "显示已删除的消息，并以 🗑 标记"
        )
    }

    // Word shown next to the timestamp on a deleted message's status line
    public var status_deletedMessage: String {
        pick(en: "Removed", uz: "O'chirilgan", ru: "Удалено", zh: "已删除")
    }

    // MARK: - Phone number context menu

    // Shown instead of "not on Telegram" when the lookup itself failed, so the app stops
    // reporting an unanswered request as a fact about the number.
    public var phoneMenu_lookupFailed: String {
        pick(
            en: "Couldn't check this number. Check your connection and try again.",
            uz: "Bu raqamni tekshirib bo'lmadi. Internetni tekshirib, qayta urinib ko'ring.",
            ru: "Не удалось проверить номер. Проверьте соединение и повторите попытку.",
            zh: "无法查询此号码。请检查网络连接后重试。"
        )
    }

    public var phoneMenu_retry: String {
        pick(en: "Try Again", uz: "Qayta urinish", ru: "Повторить", zh: "重试")
    }

    // MARK: - Round video from gallery

    public var roundVideo_preparing: String {
        pick(
            en: "Preparing video…",
            uz: "Video tayyorlanmoqda…",
            ru: "Подготовка видео…",
            zh: "正在准备视频…"
        )
    }

    public var roundVideo_preparingText: String {
        pick(
            en: "Copying the video out of your photo library. If it is stored in iCloud it has to be downloaded first, which can take a while.",
            uz: "Video galereyadan nusxalanmoqda. Agar u iCloud'da saqlangan boʻlsa, avval yuklab olinadi — bu biroz vaqt olishi mumkin.",
            ru: "Видео копируется из медиатеки. Если оно хранится в iCloud, сначала будет загружено — это может занять время.",
            zh: "正在从照片图库中复制视频。如果视频存储在 iCloud 中，需要先下载，这可能需要一些时间。"
        )
    }

    public var roundVideo_cancel: String {
        pick(en: "Cancel", uz: "Bekor qilish", ru: "Отмена", zh: "取消")
    }

    public var roundVideo_failedTitle: String {
        pick(en: "Couldn't send", uz: "Yuborib bo'lmadi", ru: "Не удалось отправить", zh: "无法发送")
    }

    public var roundVideo_failedText: String {
        pick(
            en: "This video couldn't be prepared. It may still be downloading from iCloud — try again once it is on this device.",
            uz: "Bu videoni tayyorlab bo'lmadi. U hali iCloud'dan yuklanayotgan bo'lishi mumkin — qurilmaga tushgach qayta urinib ko'ring.",
            ru: "Не удалось подготовить это видео. Возможно, оно ещё загружается из iCloud — попробуйте снова, когда оно будет на устройстве.",
            zh: "无法准备此视频。它可能仍在从 iCloud 下载——请在视频下载到此设备后重试。"
        )
    }

    public var roundVideo_ok: String {
        pick(en: "OK", uz: "OK", ru: "OK", zh: "确定")
    }

    public var settings_chat_footer: String {
        pick(
            en: "Changes apply to all chats immediately.",
            uz: "O'zgarishlar barcha chatlarga darhol qo'llaniladi.",
            ru: "Изменения применяются ко всем чатам мгновенно.",
            zh: "更改会立即应用到所有聊天。"
        )
    }

    // Interface section
    public var settings_interface_hideFolders_title: String {
        pick(en: "Hide folders", uz: "Jildlarni yashirish", ru: "Скрыть папки", zh: "隐藏分组")
    }

    public var settings_interface_hideFolders_subtitle: String {
        pick(
            en: "Temporarily hide folders at the top of the chat list",
            uz: "Chatlar ro'yxati tepasidagi jildlarni vaqtinchalik berkitish",
            ru: "Временно скрыть папки в верхней части списка чатов",
            zh: "暂时隐藏聊天列表顶部的分组"
        )
    }

    public var settings_interface_stories_title: String {
        pick(en: "Stories panel", uz: "Hikoyalar paneli", ru: "Панель историй", zh: "动态栏")
    }

    public var settings_interface_stories_subtitle: String {
        pick(
            en: "Show stories at the top of the chat list",
            uz: "Chatlar ro'yxati tepasida hikoyalarni ko'rsatish",
            ru: "Показывать истории над списком чатов",
            zh: "在聊天列表顶部显示动态"
        )
    }

    public var settings_interface_mutualSymbol_title: String {
        pick(en: "Mutual contact badge", uz: "Mutual kontakt belgisi", ru: "Значок взаимного контакта", zh: "双向联系人标记")
    }

    public var settings_interface_mutualSymbol_subtitle: String {
        pick(
            en: "Show the 🤝 badge in the contacts list",
            uz: "Kontaktlar ro'yxatida 🤝 belgisini ko'rsatish",
            ru: "Показывать значок 🤝 в списке контактов",
            zh: "在联系人列表中显示 🤝 标记"
        )
    }

    public var settings_interface_footer: String {
        pick(
            en: "Affects only this device.",
            uz: "Faqat sizning qurilmangizga ta'sir qiladi.",
            ru: "Влияет только на это устройство.",
            zh: "仅对此设备生效。"
        )
    }

    // Unread message reminder section (Xabar eslatmasi)
    public var settings_reminder_sectionTitle: String {
        pick(en: "Message reminder", uz: "Xabar eslatmasi", ru: "Напоминание о сообщении", zh: "消息提醒")
    }

    public var settings_reminder_enabled_title: String {
        pick(en: "Unread message reminder", uz: "O'qilmagan xabar eslatmasi", ru: "Напоминание о непрочитанном", zh: "未读消息提醒")
    }

    public var settings_reminder_enabled_subtitle: String {
        pick(
            en: "Reminds you about a message left unread within the set time",
            uz: "Belgilangan vaqt ichida o'qilmagan xabarni eslatadi",
            ru: "Напоминает о сообщении, не прочитанном в течение заданного времени",
            zh: "消息在设定时间内未读时提醒你"
        )
    }

    public var settings_reminder_time_title: String {
        pick(en: "Reminder time", uz: "Eslatma vaqti", ru: "Время напоминания", zh: "提醒时间")
    }

    public var settings_reminder_sound_title: String {
        pick(en: "Reminder sound", uz: "Eslatma ovozi", ru: "Звук напоминания", zh: "提醒铃声")
    }

    public var settings_reminder_footer: String {
        pick(
            en: "When the app is in the background and messages stay unread for the set time, a reminder is shown.",
            uz: "Ilova fonda bo'lganda va xabarlar belgilangan vaqt davomida o'qilmay qolsa, eslatma ko'rsatiladi.",
            ru: "Когда приложение в фоне и сообщения остаются непрочитанными заданное время, показывается напоминание.",
            zh: "当应用在后台运行，且消息在设定时间内一直未读时，将显示提醒。"
        )
    }

    // Minute-option label for the reminder-time picker, e.g. "5 min".
    public func settings_reminder_minutesLabel(_ minutes: Int) -> String {
        switch langCode {
        case "uz": return "\(minutes) daqiqa"
        case "ru": return "\(minutes) мин"
        case "zh": return "\(minutes) 分钟"
        default:   return "\(minutes) min"
        }
    }

    // Sound-option display name. Key is one of the FenixuzUnreadReminderSettings.soundOptions.
    public func settings_reminder_soundName(_ key: String) -> String {
        switch key {
        case "none":
            return pick(en: "None", uz: "Yo'q", ru: "Нет", zh: "无")
        case "chime":
            return pick(en: "Chime", uz: "Jarang", ru: "Перезвон", zh: "钟鸣")
        case "glass":
            return pick(en: "Glass", uz: "Shisha", ru: "Стекло", zh: "玻璃")
        case "bell":
            return pick(en: "Bell", uz: "Qo'ng'iroq", ru: "Колокол", zh: "铃铛")
        case "note":
            return pick(en: "Note", uz: "Nota", ru: "Нота", zh: "音符")
        case "tritone":
            return pick(en: "Tri-tone", uz: "Uch ohang", ru: "Три-тон", zh: "三全音")
        case "marimba":
            return pick(en: "Marimba", uz: "Marimba", ru: "Маримба", zh: "马林巴")
        case "crystal":
            return pick(en: "Crystal", uz: "Kristall", ru: "Кристалл", zh: "水晶")
        case "droplet":
            return pick(en: "Droplet", uz: "Tomchi", ru: "Капля", zh: "水滴")
        case "ping":
            return pick(en: "Ping", uz: "Ping", ru: "Пинг", zh: "叮")
        case "pulse":
            return pick(en: "Pulse", uz: "Puls", ru: "Пульс", zh: "脉冲")
        case "harp":
            return pick(en: "Harp", uz: "Arfa", ru: "Арфа", zh: "竖琴")
        case "signal":
            return pick(en: "Signal", uz: "Signal", ru: "Сигнал", zh: "信号")
        default:
            return pick(en: "Default notification sound", uz: "Bildirishnoma ovozi", ru: "Звук уведомления по умолчанию", zh: "默认通知音")
        }
    }

    // Chat tools section
    public var settings_chat_firstMessage_title: String {
        pick(en: "Jump to first message", uz: "Birinchi xabarga o'tish", ru: "К первому сообщению", zh: "跳转到第一条消息")
    }

    public var settings_chat_firstMessage_subtitle: String {
        pick(
            en: "Add a “View First Message” entry to the profile menu",
            uz: "Profil menyusida \"View First Message\" tugmasini qo'shish",
            ru: "Добавить пункт «Перейти к первому сообщению» в меню профиля",
            zh: "在资料页菜单中添加“View First Message”选项"
        )
    }

    public var settings_chat_ghost_title: String {
        pick(en: "Ghost mode button", uz: "Ghost rejimi tugmasi", ru: "Кнопка режима «Призрак»", zh: "幽灵模式按钮")
    }

    public var settings_chat_ghost_subtitle: String {
        pick(
            en: "Quick Ghost-mode toggle at the top of the chat list",
            uz: "Chatlar ro'yxati tepasida tezkor Ghost rejimi tugmasi",
            ru: "Быстрое переключение «Призрак» над списком чатов",
            zh: "在聊天列表顶部快速切换幽灵模式"
        )
    }

    public var settings_chat_camera_title: String {
        pick(en: "Camera picker", uz: "Kamerani tanlash", ru: "Выбор камеры", zh: "摄像头选择")
    }

    public var settings_chat_forwardHideNames_title: String {
        pick(en: "Forward Without Name", uz: "Imzosiz forward", ru: "Пересылка без имени", zh: "隐藏来源转发")
    }
    public var settings_chat_forwardHideNames_subtitle: String {
        pick(en: "Adds a “Forward without name” item to the message menu", uz: "Xabar menyusiga \"Imzosiz forward qilish\" tugmasini qo'shadi", ru: "Добавляет пункт «Переслать без имени» в меню сообщения", zh: "在消息菜单中添加“隐藏来源转发”选项")
    }
    public var context_forwardWithoutName: String {
        pick(en: "Forward without name", uz: "Imzosiz forward qilish", ru: "Переслать без имени", zh: "隐藏来源转发")
    }
    public var context_editHistory: String {
        pick(en: "Edit History", uz: "Tahrirlash tarixi", ru: "История правок", zh: "编辑记录")
    }
    public var settings_interface_unlimitedPins_title: String {
        pick(en: "Unlimited Pins", uz: "Cheksiz pin", ru: "Безлимитные закрепы", zh: "无限置顶")
    }
    public var settings_interface_unlimitedPins_subtitle: String {
        pick(
            en: "Pin up to 1000 chats. Only the first few sync to Telegram — the rest live on this iPhone only and will not appear on Android, Web or Desktop. Turning this off removes them.",
            uz: "1000 tagacha chat pin qiling. Faqat dastlabki bir nechtasi Telegram bilan sinxronlanadi — qolganlari faqat shu iPhone'da, Android, Web va Desktop'da koʻrinmaydi. Oʻchirsangiz ular olib tashlanadi.",
            ru: "Закрепляйте до 1000 чатов. С Telegram синхронизируются только первые несколько — остальные живут только на этом iPhone и не появятся в Android, Web и Desktop. При отключении они удаляются.",
            zh: "最多可置顶 1000 个聊天。只有前几个会同步到 Telegram——其余的仅保存在这台 iPhone 上，不会出现在 Android、Web 或桌面端。关闭此功能会移除它们。"
        )
    }
    public var profile_idCopied: String {
        pick(en: "ID copied", uz: "ID nusxalandi", ru: "ID скопирован", zh: "已复制 ID")
    }
    public var settings_chat_roundVideoGallery_title: String {
        pick(en: "Round video from gallery", uz: "Galereyadan dumaloq video", ru: "Круглое видео из галереи", zh: "从相册发送圆形视频")
    }

    public var settings_chat_roundVideoGallery_subtitle: String {
        pick(
            en: "Adds a \"Photos\" option to the video-message camera menu to send any gallery video as a round video. Max 1 minute — a longer video is cut to its first minute.",
            uz: "Video xabar kamera menyusiga \"Galereya\" qoʻshib, istalgan videoni dumaloq video qilib yuborish. Eng koʻpi 1 daqiqa — uzunroq video birinchi daqiqasigacha kesiladi.",
            ru: "Добавляет \"Галерею\" в меню камеры для отправки любого видео кружком. Максимум 1 минута — более длинное видео обрезается до первой минуты.",
            zh: "在视频消息的摄像头菜单中添加“相册”选项，可将相册中的任意视频作为圆形视频发送。最长 1 分钟——更长的视频只保留前 1 分钟。"
        )
    }

    public var settings_chat_camera_subtitle: String {
        pick(
            en: "Long-press the video-message button to switch front/back camera",
            uz: "Video xabar tugmasini uzun bosib old/orqa kamerani tanlash",
            ru: "Долгое нажатие на кнопку видео-сообщения переключает камеру",
            zh: "长按视频消息按钮可切换前置/后置摄像头"
        )
    }

    // Messaging section
    public var settings_messaging_textStyle_title: String {
        pick(en: "Text style", uz: "Yozuv uslubi", ru: "Стиль текста", zh: "文字样式")
    }

    public var settings_messaging_autoText_title: String {
        pick(en: "Auto-text suffix", uz: "Avto-matn qo'shimchasi", ru: "Авто-постфикс", zh: "自动后缀")
    }

    public var settings_messaging_autoTranslate_title: String {
        pick(en: "Auto-translate", uz: "Avto-tarjima", ru: "Авто-перевод", zh: "自动翻译")
    }

    public var settings_messaging_translateToggle_title: String {
        pick(en: "Translate button", uz: "Tarjima tugmasi", ru: "Кнопка перевода", zh: "翻译按钮")
    }

    public var settings_messaging_translateToggle_subtitle: String {
        pick(
            en: "Show “Translate” in the message context menu",
            uz: "Xabar context menyusida \"Translate\" ko'rsatilsin",
            ru: "Показывать «Перевести» в контекстном меню сообщения",
            zh: "在消息菜单中显示“翻译”"
        )
    }

    public var settings_messaging_translateLanguage_title: String {
        pick(en: "Translation language", uz: "Tarjima tili", ru: "Язык перевода", zh: "翻译语言")
    }

    public var settings_messaging_footer: String {
        pick(
            en: "Controls the appearance and translation of outgoing messages.",
            uz: "Yuboriladigan xabarlarning ko'rinishi va tarjimasini boshqaradi.",
            ru: "Управляет видом и переводом исходящих сообщений.",
            zh: "控制发出消息的样式和翻译。"
        )
    }

    // Voice section
    public var settings_voice_stt_title: String {
        pick(en: "Voice to text", uz: "Ovozni matnga o'girish", ru: "Голос в текст", zh: "语音转文字")
    }

    public var settings_voice_stt_subtitle: String {
        pick(
            en: "Show the STT shortcut near the microphone",
            uz: "Mikrofon yonida tezkor STT tugmasini ko'rsatish",
            ru: "Кнопка распознавания рядом с микрофоном",
            zh: "在麦克风旁显示语音转文字快捷按钮"
        )
    }

    public var settings_voice_sttLang_title: String {
        pick(en: "Recognition language", uz: "Tanish tili", ru: "Язык распознавания", zh: "识别语言")
    }

    // Protection section
    public var settings_protection_foreign_title: String {
        pick(en: "Block foreign numbers", uz: "Xorijiy raqamlarni bloklash", ru: "Блокировать иностранные номера", zh: "屏蔽境外号码")
    }

    public var settings_protection_foreign_subtitle: String {
        pick(
            en: "Automatically block messages from numbers in other countries",
            uz: "Boshqa davlat raqamlaridan kelgan xabarlarni avtomatik bloklash",
            ru: "Автоматически блокировать сообщения с зарубежных номеров",
            zh: "自动屏蔽来自其他国家或地区号码的消息"
        )
    }

    public var settings_protection_footer: String {
        pick(
            en: "Protection from spam and harmful content.",
            uz: "Spam va zararli kontentdan himoya.",
            ru: "Защита от спама и вредоносного контента.",
            zh: "防范垃圾消息和有害内容。"
        )
    }

    // MARK: - Text style picker

    public func textStyle_displayName(_ key: String) -> String {
        switch key {
        case "bold":
            return pick(en: "Bold", uz: "Qalin (Bold)", ru: "Жирный (Bold)", zh: "粗体")
        case "italic":
            return pick(en: "Italic", uz: "Kiyshiq (Italic)", ru: "Курсив (Italic)", zh: "斜体")
        case "monospace":
            return pick(en: "Monospace (Code)", uz: "Monospace (Kod)", ru: "Моноширинный (Код)", zh: "等宽（代码）")
        case "strikethrough":
            return pick(en: "Strikethrough", uz: "Chizilgan (Strikethrough)", ru: "Зачёркнутый (Strikethrough)", zh: "删除线")
        case "underline":
            return pick(en: "Underline", uz: "Tagiga chizilgan (Underline)", ru: "Подчёркнутый (Underline)", zh: "下划线")
        case "spoiler":
            return "Spoiler" // Same word in all locales
        default:
            return pick(en: "Plain (None)", uz: "Uslubsiz (Oddiy)", ru: "Без стиля (Обычный)", zh: "普通（无样式）")
        }
    }

    public func textStyle_example(_ key: String) -> String {
        switch key {
        case "bold":
            return pick(
                en: "Example: Hi, this message will be sent in Bold style",
                uz: "Misol: Salom, bu xabar qalin (Bold) ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено жирным (Bold)",
                zh: "示例：你好，这条消息将以粗体发送"
            )
        case "italic":
            return pick(
                en: "Example: Hi, this message will be sent in Italic style",
                uz: "Misol: Salom, bu xabar kiyshiq (Italic) ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено курсивом (Italic)",
                zh: "示例：你好，这条消息将以斜体发送"
            )
        case "monospace":
            return pick(
                en: "Example: Hi, this message will be sent in monospace (code) style",
                uz: "Misol: Salom, bu xabar monospace (kod) ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено моноширинным (код)",
                zh: "示例：你好，这条消息将以等宽（代码）样式发送"
            )
        case "strikethrough":
            return pick(
                en: "Example: Hi, this message will be sent strikethrough",
                uz: "Misol: Salom, bu xabar chizilgan ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено зачёркнутым",
                zh: "示例：你好，这条消息将带删除线发送"
            )
        case "underline":
            return pick(
                en: "Example: Hi, this message will be sent underlined",
                uz: "Misol: Salom, bu xabar tagiga chizilgan ko'rinishda yuboriladi",
                ru: "Пример: Привет, это сообщение будет отправлено подчёркнутым",
                zh: "示例：你好，这条消息将带下划线发送"
            )
        case "spoiler":
            return pick(
                en: "Example: Hi, this message will be sent as a spoiler (tap to reveal)",
                uz: "Misol: Salom, bu xabar spoiler ko'rinishda yuboriladi (bosib ko'rish kerak)",
                ru: "Пример: Привет, это сообщение будет отправлено как спойлер (нажмите, чтобы открыть)",
                zh: "示例：你好，这条消息将以剧透（Spoiler）形式发送，点击后才会显示"
            )
        default:
            return pick(
                en: "No style selected. Messages will be sent as plain text",
                uz: "Uslub tanlanmagan. Xabarlar oddiy matn sifatida yuboriladi",
                ru: "Стиль не выбран. Сообщения будут отправлены обычным текстом",
                zh: "未选择样式。消息将以纯文本发送"
            )
        }
    }

    // MARK: - App Store IAP compliance (Apple guideline 3.1.1)

    public var iap_block_title: String {
        pick(
            en: "Telegram Premium",
            uz: "Telegram Premium",
            ru: "Telegram Premium",
            zh: "Telegram Premium"
        )
    }

    public var iap_block_message: String {
        pick(
            en: "Telegram Premium is purchased through the official Telegram app. Continue to Telegram Premium to complete your subscription.",
            uz: "Telegram Premium rasmiy Telegram ilovasi orqali sotib olinadi. Obunani yakunlash uchun Telegram Premium'ga o'ting.",
            ru: "Telegram Premium приобретается в официальном приложении Telegram. Перейдите в Telegram Premium, чтобы оформить подписку.",
            zh: "Telegram Premium 需通过官方 Telegram 应用购买。请前往 Telegram Premium 完成订阅。"
        )
    }

    public var iap_block_open_app_store: String {
        pick(
            en: "Open Telegram Premium",
            uz: "Telegram Premium'ni ochish",
            ru: "Открыть Telegram Premium",
            zh: "打开 Telegram Premium"
        )
    }

    public var iap_block_cancel: String {
        pick(
            en: "Cancel",
            uz: "Bekor qilish",
            ru: "Отмена",
            zh: "取消"
        )
    }

    // MARK: - All Accounts (multi-account working-set)

    public var accounts_allAccounts: String {
        pick(en: "All Accounts", uz: "Barcha accountlar", ru: "Все аккаунты", zh: "所有账号")
    }

    public var accounts_sectionHeader: String {
        pick(en: "ACCOUNTS", uz: "ACCOUNTLAR", ru: "АККАУНТЫ", zh: "账号")
    }

    public func accounts_summary(total: Int, active: Int) -> String {
        pick(
            en: "TOTAL: \(total) accounts · \(active) active",
            uz: "JAMI: \(total) ta account · \(active) ta faol",
            ru: "ВСЕГО: \(total) аккаунтов · \(active) активных",
            zh: "总计：\(total) 个账号 · \(active) 个活跃"
        )
    }

    public var accounts_current: String {
        pick(en: "Current", uz: "Joriy", ru: "Текущий", zh: "当前")
    }

    public var accounts_active: String {
        pick(en: "Active", uz: "Faol", ru: "Активный", zh: "活跃")
    }

    public var accounts_sleeping: String {
        pick(en: "Sleeping", uz: "Uyquda", ru: "Спит", zh: "休眠中")
    }

    public var accounts_accountFallback: String {
        pick(en: "Account", uz: "Hisob", ru: "Аккаунт", zh: "账号")
    }

    // VoiceOver: read out after the account title + status pill.
    public var accounts_a11ySwitchHint: String {
        pick(
            en: "Double-tap to switch to this account",
            uz: "Bu accountga o'tish uchun ikki marta bosing",
            ru: "Дважды коснитесь, чтобы перейти в этот аккаунт",
            zh: "连按两次以切换到此账号"
        )
    }

    public var accounts_footer: String {
        pick(
            en: "Up to 5 accounts can run live at once. Long-press any account to Activate (keep live) or Put to Sleep. The current account is always live. Sleeping accounts still receive notifications and wake up in 1–2 seconds when selected. This way even 100+ accounts won't slow your phone.",
            uz: "Bir vaqtda 5 tagacha account jonli ishlashi mumkin. Istalgan accountga uzoq bosib, uni Faollashtiring (jonli saqlanadi) yoki Uyquga qo'ying. Joriy account doim jonli bo'ladi. Uyqudagi accountlar bildirishnoma oladi va tanlaganda 1–2 soniyada jonlanadi. Shu tarzda 100+ account ham telefonni sekinlashtirmaydi.",
            ru: "До 5 аккаунтов могут работать одновременно. Зажмите любой аккаунт, чтобы Активировать (держать активным) или Усыпить. Текущий аккаунт всегда активен. Спящие аккаунты получают уведомления и просыпаются за 1–2 секунды при выборе. Так даже 100+ аккаунтов не замедлят телефон.",
            zh: "最多可同时让 5 个账号保持运行。长按任意账号，可选择“激活”（保持运行）或“设为休眠”。当前账号始终保持运行。休眠中的账号仍会收到通知，选中后 1–2 秒即可唤醒。这样即使有 100+ 个账号，也不会拖慢你的手机。"
        )
    }

    // Tab-bar long-press account switcher
    public var accounts_switchTo: String {
        pick(en: "Switch account", uz: "Accountni almashtirish", ru: "Сменить аккаунт", zh: "切换账号")
    }

    public var accounts_tabBarSwitchTitle: String {
        pick(en: "Switch to…", uz: "O'tish…", ru: "Перейти в…", zh: "切换到…")
    }

    // MARK: - Tips / Imkoniyatlar (Feature guide)

    public var tips_screenTitle: String {
        pick(en: "Features", uz: "Imkoniyatlar", ru: "Возможности", zh: "功能")
    }

    public var tips_closeButton: String {
        pick(en: "Got it!", uz: "Tushunarli!", ru: "Понятно!", zh: "知道了")
    }

    // Ghost mode
    public var tips_ghost_title: String {
        pick(en: "Ghost Mode", uz: "Ghost rejimi", ru: "Режим «Призрак»", zh: "幽灵模式")
    }

    public var tips_ghost_body: String {
        pick(
            en: "Read messages without sending read receipts. Toggle the ghost icon at the top of your chat list — no one will know you were there.",
            uz: "Xabarlarni o'qildi belgisi yubormasdan o'qing. Chatlar ro'yxati tepasidagi ghost ikonkasini bosing — hech kim bilmaydi.",
            ru: "Читайте сообщения без отправки уведомлений о прочтении. Нажмите иконку призрака вверху списка чатов — никто не узнает.",
            zh: "阅读消息而不发送已读回执。点击聊天列表顶部的幽灵图标即可开关——没有人会知道你来过。"
        )
    }

    // Speech to text
    public var tips_stt_title: String {
        pick(en: "Voice → Text (STT)", uz: "Ovoz → Matn (STT)", ru: "Голос → Текст (STT)", zh: "语音 → 文字（STT）")
    }

    public var tips_stt_body: String {
        pick(
            en: "Tap the microphone button next to the text field to convert voice to text instantly. Enable it in Novagram → Voice → Text settings.",
            uz: "Matn maydonidagi mikrofon tugmasini bosib, ovozingizni darhol matnga aylantiring. Novagram → Ovoz → Matn sozlamalarida yoqing.",
            ru: "Нажмите кнопку микрофона рядом с полем ввода, чтобы мгновенно преобразовать голос в текст. Включите в настройках Novagram → Голос → Текст.",
            zh: "点击输入框旁的麦克风按钮，即可将语音即时转为文字。可在“Novagram → 语音 → 文字”设置中开启。"
        )
    }

    // Multi-account
    public var tips_multiAccount_title: String {
        pick(en: "100+ Accounts", uz: "100+ Account", ru: "100+ Аккаунтов", zh: "100+ 账号")
    }

    public var tips_multiAccount_body: String {
        pick(
            en: "Add as many Telegram accounts as you need. Only the active one runs — the rest sleep but still receive notifications. Switch in 1–2 seconds without slowing your phone.",
            uz: "Xohlagancha Telegram akkauntlarini qo'shing. Faqat tanlangan akkaunt ishlaydi — qolganlar uyquda, ammo bildirishnomalar kelaveradi. 1–2 soniyada almashing, telefon sekinlashmaydi.",
            ru: "Добавляйте любое количество аккаунтов Telegram. Активен только выбранный — остальные спят, но уведомления продолжают приходить. Переключение за 1–2 секунды без замедления телефона.",
            zh: "按需添加任意数量的 Telegram 账号。只有当前账号在运行——其余账号处于休眠状态，但仍会收到通知。1–2 秒即可切换，不会拖慢手机。"
        )
    }

    // Edited message history
    public var tips_editedHistory_title: String {
        pick(en: "Edited Message History", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений", zh: "消息编辑记录")
    }

    public var tips_editedHistory_body: String {
        pick(
            en: "See every previous version of an edited message. Long-press any edited message and choose \"Editing history\" to view all changes.",
            uz: "Tahrirlangan xabarning barcha oldingi versiyalarini ko'ring. Tahrirlangan xabarga uzoq bosib, \"Tahrir tarixi\"ni tanlang.",
            ru: "Смотрите все предыдущие версии отредактированных сообщений. Зажмите любое отредактированное сообщение и выберите «История правок».",
            zh: "查看已编辑消息的每个历史版本。长按任意已编辑的消息，选择“编辑记录”即可查看所有更改。"
        )
    }

    // Chat lock
    public var tips_chatLock_title: String {
        pick(en: "Chat Lock (PIN)", uz: "Chat qulfi (PIN)", ru: "Блокировка чатов (PIN)", zh: "聊天锁（密码）")
    }

    public var tips_chatLock_body: String {
        pick(
            en: "Protect individual chats with a PIN code. Only you can open locked chats — even if someone picks up your phone.",
            uz: "Alohida chatlarni PIN kod bilan himoyalang. Qulflangan chatni faqat siz ochishingiz mumkin.",
            ru: "Защитите отдельные чаты PIN-кодом. Заблокированный чат откроете только вы — даже если телефон окажется в чужих руках.",
            zh: "使用密码保护单个聊天。只有你能打开已锁定的聊天——即使别人拿到了你的手机也不行。"
        )
    }

    // Auto-text
    public var tips_autoText_title: String {
        pick(en: "Auto-Text Suffix", uz: "Avto-matn qo'shimchasi", ru: "Авто-постфикс", zh: "自动后缀")
    }

    public var tips_autoText_body: String {
        pick(
            en: "Automatically add a custom text at the end of every outgoing message — a signature, hashtag, or anything you like. Configure in Novagram → Messages.",
            uz: "Har bir chiquvchi xabar oxiriga avtomatik matn qo'shing — imzo, hashtag yoki xohlagan narsa. Novagram → Xabarlar sozlamalarida o'rnatiladi.",
            ru: "Автоматически добавляйте произвольный текст в конец каждого исходящего сообщения — подпись, хэштег или что угодно. Настраивается в Novagram → Сообщения.",
            zh: "在每条发出的消息末尾自动添加自定义文字——签名、话题标签或任何你喜欢的内容。可在“Novagram → 消息”中设置。"
        )
    }

    // Translate
    public var tips_translate_title: String {
        pick(en: "Instant Translation", uz: "Tezkor tarjima", ru: "Мгновенный перевод", zh: "即时翻译")
    }

    public var tips_translate_body: String {
        pick(
            en: "Translate any message with one tap. Long-press a message and choose \"Translate\". Enable the button in Novagram → Messages settings.",
            uz: "Har qanday xabarni bir teginishda tarjima qiling. Xabarga uzoq bosib, \"Tarjima\" ni tanlang. Novagram → Xabarlar sozlamalarida yoqiladi.",
            ru: "Переводите любое сообщение одним нажатием. Зажмите сообщение и выберите «Перевести». Включается в настройках Novagram → Сообщения.",
            zh: "一键翻译任意消息。长按消息并选择“翻译”。可在“Novagram → 消息”设置中开启该按钮。"
        )
    }

    // Fenixuz Settings hub
    public var tips_fenixHub_title: String {
        pick(en: "Novagram Settings Hub", uz: "Novagram sozlamalari markazi", ru: "Центр настроек Novagram", zh: "Novagram 设置中心")
    }

    public var tips_fenixHub_body: String {
        pick(
            en: "All Novagram features in one place. Open your Settings and tap the gold \"Novagram\" row to access Ghost mode, STT, auto-text, translate, chat lock, and more.",
            uz: "Barcha Novagram imkoniyatlari bir joyda. Sozlamalarga kirib, oltin rang \"Novagram\" qatoriga bosing — Ghost rejimi, STT, avto-matn, tarjima, chat qulfi va boshqalar.",
            ru: "Все функции Novagram в одном месте. Откройте Настройки и нажмите золотую строку «Novagram» — Ghost-режим, STT, авто-текст, перевод, блокировка чатов и многое другое.",
            zh: "所有 Novagram 功能集中在一处。打开设置，点击金色的“Novagram”一栏，即可使用幽灵模式、语音转文字、自动后缀、翻译、聊天锁等功能。"
        )
    }

    // MARK: - Edited message history toggle

    public var settings_chat_editedHistory_title: String {
        pick(en: "Edited message history", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений", zh: "消息编辑记录")
    }

    public var settings_chat_editedHistory_subtitle: String {
        pick(
            en: "Long-press any edited message to view all previous versions",
            uz: "Tahrirlangan xabarga uzoq bosib barcha oldingi versiyalarni ko'ring",
            ru: "Зажмите отредактированное сообщение, чтобы увидеть все предыдущие версии",
            zh: "长按任意已编辑的消息，即可查看所有历史版本"
        )
    }

    // MARK: - Alternate app icon names (Settings -> App Icon picker)

    public var iconName_default: String {
        pick(en: "Default", uz: "Asosiy", ru: "Основной", zh: "默认")
    }

    public var iconName_blue: String {
        pick(en: "Blue", uz: "Ko‘k", ru: "Синий", zh: "蓝色")
    }

    public var iconName_teal: String {
        pick(en: "Teal", uz: "Feruza", ru: "Бирюзовый", zh: "青色")
    }

    public var iconName_purple: String {
        pick(en: "Purple", uz: "Binafsha", ru: "Фиолетовый", zh: "紫色")
    }

    public var iconName_pink: String {
        pick(en: "Pink", uz: "Pushti", ru: "Розовый", zh: "粉色")
    }

    public var iconName_orange: String {
        pick(en: "Orange", uz: "To‘q sariq", ru: "Оранжевый", zh: "橙色")
    }

    public var iconName_black: String {
        pick(en: "Black", uz: "Qora", ru: "Чёрный", zh: "黑色")
    }

    public var iconName_red: String {
        pick(en: "Red", uz: "Qizil", ru: "Красный", zh: "红色")
    }

    // MARK: - Camera picker front/back labels

    public var cameraPicker_front: String {
        pick(en: "Front Camera", uz: "Old kamera", ru: "Передняя камера", zh: "前置摄像头")
    }

    public var cameraPicker_back: String {
        pick(en: "Back Camera", uz: "Orqa kamera", ru: "Задняя камера", zh: "后置摄像头")
    }

    public var cameraPicker_gallery: String {
        pick(en: "Photos", uz: "Galereyadan", ru: "Из галереи", zh: "相册")
    }

    // Shown instead of the Front/Back pair when only "Round video from gallery" is on —
    // the sheet still needs a way to reach the recorder, but the user did not ask for a
    // front/back choice.
    public var cameraPicker_camera: String {
        pick(en: "Camera", uz: "Kamera", ru: "Камера", zh: "相机")
    }

    // MARK: - Update check alert

    public var update_title: String {
        pick(en: "Update Available", uz: "Yangilanish mavjud", ru: "Доступно обновление", zh: "发现新版本")
    }

    public func update_message(version: String) -> String {
        pick(
            en: "A new version (\(version)) of Novagram is available on the App Store.",
            uz: "Novagram'ning yangi versiyasi (\(version)) App Store'da mavjud.",
            ru: "Новая версия Novagram (\(version)) доступна в App Store.",
            zh: "App Store 上已有 Novagram 新版本（\(version)）。"
        )
    }

    public var update_actionUpdate: String {
        pick(en: "Update", uz: "Yangilash", ru: "Обновить", zh: "更新")
    }

    public var update_actionLater: String {
        pick(en: "Later", uz: "Keyinroq", ru: "Позже", zh: "稍后")
    }

    // MARK: - Pinned accounts (no-sleep / activate)

    public var accounts_activate: String {
        pick(en: "Activate (No Sleep)", uz: "Faollashtirish (Uyqusiz)", ru: "Активировать (Без сна)", zh: "激活（不休眠）")
    }

    public var accounts_putToSleep: String {
        pick(en: "Put to Sleep", uz: "Uyquga qo'yish", ru: "Перевести в сон", zh: "设为休眠")
    }

    public var accounts_maxLiveTitle: String {
        pick(en: "Maximum Reached", uz: "Chegara yetdi", ru: "Лимит достигнут", zh: "已达上限")
    }

    public var accounts_maxLiveBody: String {
        pick(
            en: "Maximum 5 accounts can run at once — more will heat up and slow your phone. Put one to sleep first.",
            uz: "Bir vaqtda ko'pi bilan 5 ta account ishlashi mumkin — ko'proq telefon qizib, sekinlashadi. Avval birini uyquga qo'ying.",
            ru: "Одновременно может работать не более 5 аккаунтов — больше будет греть и замедлять телефон. Сначала усыпите один.",
            zh: "最多只能同时运行 5 个账号——再多会让手机发热、变慢。请先将一个账号设为休眠。"
        )
    }

    public var accounts_maxLiveOk: String {
        pick(en: "OK", uz: "OK", ru: "OK", zh: "确定")
    }

    // MARK: - QR-code login (phone entry screen)

    public var auth_qrLoginButton: String {
        pick(en: "Log in by QR code", uz: "QR kod orqali kirish", ru: "Войти по QR-коду", zh: "使用二维码登录")
    }

    // MARK: - About FenixPro (Settings → FenixPro → About)

    public var about_rowTitle: String {
        pick(en: "About Novagram", uz: "Novagram haqida", ru: "О Novagram", zh: "关于 Novagram")
    }

    public var about_screenTitle: String {
        pick(en: "About Novagram", uz: "Novagram haqida", ru: "О Novagram", zh: "关于 Novagram")
    }

    public var about_introHeader: String {
        pick(en: "WHAT IS NOVAGRAMPRO", uz: "NOVAGRAMPRO NIMA", ru: "ЧТО ТАКОЕ NOVAGRAMPRO", zh: "什么是 NovagramPro")
    }

    public var about_introBody: String {
        pick(
            en: "Novagram is Telegram with a set of extra tools built on top. Everything below is included — no subscription, no paywall. Each feature can be turned on or off in Novagram Settings.",
            uz: "Novagram — bu ustiga qo'shimcha vositalar qo'shilgan Telegram. Quyidagilarning barchasi bepul — obuna ham, to'lov ham yo'q. Har bir imkoniyatni Novagram sozlamalarida yoqish yoki o'chirish mumkin.",
            ru: "Novagram — это Telegram с набором дополнительных инструментов. Всё перечисленное ниже бесплатно — без подписки и без платного доступа. Каждую функцию можно включить или выключить в настройках Novagram.",
            zh: "Novagram 是在 Telegram 基础上加入了一系列额外工具的客户端。以下所有功能均已包含——无需订阅，也没有付费墙。每项功能都可以在 Novagram 设置中开启或关闭。"
        )
    }

    public var about_featuresHeader: String {
        pick(en: "FEATURES", uz: "IMKONIYATLAR", ru: "ВОЗМОЖНОСТИ", zh: "功能")
    }

    // Ghost mode
    public var about_ghost_title: String {
        pick(en: "Ghost Mode", uz: "Ghost rejimi", ru: "Режим «Призрак»", zh: "幽灵模式")
    }

    public var about_ghost_body: String {
        pick(
            en: "Read messages, view stories and ads, and stay online without sending a single \"seen\", \"typing\" or \"online\" signal.",
            uz: "Xabarlarni o'qing, storilar va reklamalarni ko'ring hamda \"ko'rildi\", \"yozyapti\" yoki \"onlayn\" signalini yubormasdan tarmoqda bo'ling.",
            ru: "Читайте сообщения, смотрите истории и рекламу и оставайтесь онлайн, не отправляя ни одного сигнала «просмотрено», «печатает» или «в сети».",
            zh: "阅读消息、观看动态和广告、保持在线，却不会发出任何“已读”“正在输入”或“在线”状态。"
        )
    }

    // Multi-account
    public var about_multiAccount_title: String {
        pick(en: "Multi-Account (No Sleep)", uz: "Ko'p account (Uyqusiz)", ru: "Мультиаккаунт (без сна)", zh: "多账号（不休眠）")
    }

    public var about_multiAccount_body: String {
        pick(
            en: "Keep up to 5 accounts live in the background to receive notifications, while unlimited extra accounts sleep to save battery. Switch in 1–2 seconds.",
            uz: "Bildirishnomalarni olish uchun 5 tagacha accountni fonda jonli saqlang, qolgan cheksiz accountlar batareyani tejash uchun uyquda turadi. 1–2 soniyada almashing.",
            ru: "Держите до 5 аккаунтов активными в фоне для получения уведомлений, а неограниченное число остальных спит ради экономии заряда. Переключение за 1–2 секунды.",
            zh: "最多可让 5 个账号在后台保持运行以接收通知，其余不限数量的账号将进入休眠以节省电量。1–2 秒即可切换。"
        )
    }

    // QR login
    public var about_qrLogin_title: String {
        pick(en: "QR Code Login", uz: "QR kod orqali kirish", ru: "Вход по QR-коду", zh: "二维码登录")
    }

    public var about_qrLogin_body: String {
        pick(
            en: "Sign in by scanning a QR code straight from the phone-number screen — no SMS code typing needed.",
            uz: "Telefon raqami ekranidan to'g'ridan-to'g'ri QR kodni skanerlab kiring — SMS kodni terish shart emas.",
            ru: "Входите, отсканировав QR-код прямо с экрана ввода номера — без набора кода из SMS.",
            zh: "直接在输入手机号的页面扫描二维码登录——无需输入短信验证码。"
        )
    }

    // Edited message history
    public var about_editedHistory_title: String {
        pick(en: "Edited Message History", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений", zh: "消息编辑记录")
    }

    public var about_editedHistory_body: String {
        pick(
            en: "See every previous version of an edited message. Long-press an edited message and choose \"Editing history\".",
            uz: "Tahrirlangan xabarning barcha oldingi versiyalarini ko'ring. Tahrirlangan xabarga uzoq bosib, \"Tahrir tarixi\"ni tanlang.",
            ru: "Смотрите все предыдущие версии отредактированного сообщения. Зажмите его и выберите «История правок».",
            zh: "查看已编辑消息的每个历史版本。长按已编辑的消息，然后选择“编辑记录”。"
        )
    }

    // Speech to text
    public var about_stt_title: String {
        pick(en: "Voice → Text", uz: "Ovoz → Matn", ru: "Голос → Текст", zh: "语音 → 文字")
    }

    public var about_stt_body: String {
        pick(
            en: "Convert any voice message to text on your device with the microphone button next to the chat input.",
            uz: "Chat kirish maydoni yonidagi mikrofon tugmasi bilan har qanday ovozli xabarni qurilmangizda matnga aylantiring.",
            ru: "Преобразуйте любое голосовое сообщение в текст на устройстве с помощью кнопки микрофона рядом с полем ввода.",
            zh: "使用聊天输入框旁的麦克风按钮，在设备上将任意语音消息转为文字。"
        )
    }

    // Chat lock
    public var about_chatLock_title: String {
        pick(en: "Chat Lock (PIN)", uz: "Chat qulfi (PIN)", ru: "Блокировка чатов (PIN)", zh: "聊天锁（密码）")
    }

    public var about_chatLock_body: String {
        pick(
            en: "Protect individual chats with a PIN code. Only you can open a locked chat, even if someone else picks up your phone.",
            uz: "Alohida chatlarni PIN kod bilan himoyalang. Qulflangan chatni faqat siz ochishingiz mumkin, telefon birovning qo'lida bo'lsa ham.",
            ru: "Защитите отдельные чаты PIN-кодом. Заблокированный чат откроете только вы, даже если телефон окажется у кого-то другого.",
            zh: "使用密码保护单个聊天。即使手机落入他人之手，也只有你能打开已锁定的聊天。"
        )
    }

    // Auto-text & translate
    public var about_messaging_title: String {
        pick(en: "Auto-Text & Translation", uz: "Avto-matn va tarjima", ru: "Авто-текст и перевод", zh: "自动后缀与翻译")
    }

    public var about_messaging_body: String {
        pick(
            en: "Add a custom signature to every outgoing message automatically, and translate any incoming message with one tap.",
            uz: "Har bir chiquvchi xabar oxiriga avtomatik imzo qo'shing va istalgan kelgan xabarni bir teginishda tarjima qiling.",
            ru: "Автоматически добавляйте подпись в конец каждого исходящего сообщения и переводите любое входящее сообщение одним нажатием.",
            zh: "自动为每条发出的消息添加自定义签名，并一键翻译任意收到的消息。"
        )
    }

    public var about_footer: String {
        pick(
            en: "Novagram is built on top of Telegram. All your chats, contacts and data stay in your regular Telegram account.",
            uz: "Novagram Telegram asosida qurilgan. Barcha chatlaringiz, kontaktlaringiz va ma'lumotlaringiz oddiy Telegram accountingizda qoladi.",
            ru: "Novagram построен на основе Telegram. Все ваши чаты, контакты и данные остаются в вашем обычном аккаунте Telegram.",
            zh: "Novagram 基于 Telegram 构建。你的所有聊天、联系人和数据都保留在你原有的 Telegram 账号中。"
        )
    }
}
