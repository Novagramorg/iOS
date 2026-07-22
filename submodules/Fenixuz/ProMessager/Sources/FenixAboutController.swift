import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import FenixuzLocalization

// Fenixuz "About Novagram" screen.
//
// A read-only overview of EVERY Novagram feature currently shipping in the app.
// Pushed from the Novagram settings screen ("About Novagram" row).
//
// Layout:
//   • Intro section  — header + one-paragraph product description
//   • Feature rows   — icon + title (no chevron) + footer body paragraph, one section each.
//                      Each body paragraph is split into three labeled parts: ENABLE, HOW IT
//                      WORKS, DISABLE — so a user can find and understand any feature end to end
//                      without leaving this screen.
//   • Closing footer — attribution paragraph
//
// Each feature occupies its own section so the footer paragraph wraps cleanly.
// Content here is self-contained (module-local en/uz/ru strings) rather than routed through
// the shared FenixuzL10n — this avoids a parallel-edit hazard on the Localization module and
// mirrors the existing convention used by FenixFeaturesStrings / FenixChatLockStrings elsewhere
// in this module.

// MARK: - Localized triple helper

/// Holds the same piece of copy in all three shipped languages (en default, uz, ru fallback-to-en).
private struct L3 {
    let en: String
    let uz: String
    let ru: String

    func text(_ langCode: String) -> String {
        switch langCode {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }
}

/// Localized section labels for the three-part body (Enable / How it works / Disable).
private func stepLabels(langCode: String) -> (enable: String, works: String, disable: String) {
    switch langCode {
    case "uz": return ("YOQISH", "ISHLASH TARTIBI", "O'CHIRISH")
    case "ru": return ("ВКЛЮЧЕНИЕ", "КАК РАБОТАЕТ", "ОТКЛЮЧЕНИЕ")
    default:   return ("ENABLE", "HOW IT WORKS", "DISABLE")
    }
}

// MARK: - Shared row model

private struct AboutFeature {
    let symbol: String
    let color: FenixuzIconColor
    let title: String
    let body: String
}

// MARK: - Feature spec (one entry per Novagram feature, all 3 languages + all 3 steps)

private struct FeatureSpec {
    let symbol: String
    let color: FenixuzIconColor
    let title: L3
    let enable: L3
    let works: L3
    let disable: L3

    func asAboutFeature(langCode: String) -> AboutFeature {
        let labels = stepLabels(langCode: langCode)
        let body = "\(labels.enable): \(enable.text(langCode))\n\n\(labels.works): \(works.text(langCode))\n\n\(labels.disable): \(disable.text(langCode))"
        return AboutFeature(symbol: symbol, color: color, title: title.text(langCode), body: body)
    }
}

// MARK: - Every Novagram feature — how to enable, how it works, how to disable

private func allFeatureSpecs() -> [FeatureSpec] {
    return [
        // 1. Ghost Mode
        FeatureSpec(
            symbol: "eye.slash.fill", color: .gray,
            title: L3(en: "Ghost Mode", uz: "Ghost rejimi", ru: "Режим «Призрак»"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Ghost mode button”. A ghost icon appears above your chat list — tap it any time to toggle ghost mode instantly.",
                uz: "Sozlamalar → Novagram → Chat → \"Ghost rejimi tugmasi\"ni yoqing. Chatlar ro'yxati tepasida ghost ikonkasi paydo bo'ladi — istalgan vaqt bosib yoqing yoki o'chiring.",
                ru: "Настройки → Novagram → Чат → включите «Кнопка режима Призрак». Над списком чатов появится значок призрака — нажимайте его в любой момент."
            ),
            works: L3(
                en: "While active, you can read messages, view stories and ads, and stay online without ever sending a “seen”, “typing” or “online” signal to the other side.",
                uz: "Yoqilgan holatda xabarlarni o'qiysiz, storilar va reklamalarni ko'rasiz hamda onlayn turasiz — lekin \"ko'rildi\", \"yozyapti\" yoki \"onlayn\" signali hech kimga yuborilmaydi.",
                ru: "Пока включено, вы читаете сообщения, смотрите истории и рекламу и остаётесь онлайн, не отправляя ни одного сигнала «просмотрено», «печатает» или «в сети»."
            ),
            disable: L3(
                en: "Tap the ghost icon again, or turn the same switch off in Settings → Novagram → Chat. Read receipts resume normally.",
                uz: "Ghost ikonkasini yana bosing yoki Sozlamalar → Novagram → Chat bo'limida shu switchni o'chiring. \"Ko'rildi\" signali odatdagidek qaytadi.",
                ru: "Нажмите значок призрака ещё раз или выключите тот же переключатель в Настройки → Novagram → Чат. Уведомления о прочтении возобновятся."
            )
        ),
        // 2. Multi-Account (No Sleep)
        FeatureSpec(
            symbol: "person.2.fill", color: .blue,
            title: L3(en: "Multi-Account (No Sleep)", uz: "Ko'p account (Uyqusiz)", ru: "Мультиаккаунт (без сна)"),
            enable: L3(
                en: "Add accounts the normal Telegram way (Settings → Add Account). Long-press any account row in the account switcher and choose “Activate (No Sleep)” to keep up to 5 accounts live at once.",
                uz: "Akkauntlarni odatdagidek qo'shing (Sozlamalar → Add Account). Akkaunt almashtirgichida istalgan akkauntga uzoq bosib \"Faollashtirish (Uyqusiz)\"ni tanlang — bir vaqtda 5 tagacha akkaunt jonli turadi.",
                ru: "Добавляйте аккаунты обычным способом Telegram (Настройки → Add Account). Зажмите любой аккаунт в переключателе и выберите «Активировать (Без сна)» — до 5 аккаунтов будут активны одновременно."
            ),
            works: L3(
                en: "Only active (non-sleeping) accounts keep an open connection; the rest sleep to save battery but still receive push notifications and wake up in 1–2 seconds when you switch to them. This lets you run 100+ accounts without slowing your phone down.",
                uz: "Faqat faol (uyqusiz) akkauntlar doim ochiq ulanishda turadi; qolganlari batareyani tejash uchun uyquda, lekin bildirishnoma kelaveradi va tanlaganda 1–2 soniyada jonlanadi. Shu tarzda 100+ akkaunt ham telefonni sekinlashtirmaydi.",
                ru: "Только активные (не спящие) аккаунты держат открытое соединение; остальные спят ради экономии заряда, но получают push-уведомления и просыпаются за 1–2 секунды при переключении. Так можно держать 100+ аккаунтов без замедления телефона."
            ),
            disable: L3(
                en: "Long-press an activated account and choose “Put to Sleep” to release its live slot. Sleeping is the default state for every account beyond the current one.",
                uz: "Faollashtirilgan akkauntga uzoq bosib \"Uyquga qo'yish\"ni tanlang — jonli o'rin bo'shaydi. Joriy akkaunt tashqarisidagi har qanday akkaunt uchun uyqu — standart holat.",
                ru: "Зажмите активированный аккаунт и выберите «Перевести в сон» — активный слот освободится. Сон — состояние по умолчанию для всех аккаунтов, кроме текущего."
            )
        ),
        // 3. QR Code Login
        FeatureSpec(
            symbol: "qrcode", color: .violet,
            title: L3(en: "QR Code Login", uz: "QR kod orqali kirish", ru: "Вход по QR-коду"),
            enable: L3(
                en: "On the phone-number login screen, tap the QR icon in the top-right corner of the navigation bar.",
                uz: "Telefon raqami kiritish ekranida, yuqori o'ng burchakdagi QR ikonkasini bosing.",
                ru: "На экране входа по номеру телефона нажмите значок QR в правом верхнем углу навигационной панели."
            ),
            works: L3(
                en: "A QR code appears — scan it from an already-logged-in Telegram/Novagram app (Settings → Devices → Link Desktop Device) to sign in instantly, without typing an SMS code.",
                uz: "QR kod chiqadi — uni allaqachon tizimga kirgan Telegram/Novagram ilovasidan skanerlang (Sozlamalar → Qurilmalar → Link Desktop Device) — SMS kodni terish shart emas.",
                ru: "Появится QR-код — отсканируйте его из уже авторизованного приложения Telegram/Novagram (Настройки → Устройства → Подключить устройство) и войдите мгновенно, без ввода SMS-кода."
            ),
            disable: L3(
                en: "Tap the back arrow inside the QR overlay, or Cancel, to return to normal phone-number entry. There is no persistent toggle — it's a one-time action per login attempt.",
                uz: "QR oynasi ichidagi orqaga strelkasini yoki Bekor qilish tugmasini bosib, oddiy telefon raqami kiritishga qaytishingiz mumkin. Doimiy switch yo'q — bu har safar login uchun bir martalik amal.",
                ru: "Нажмите стрелку назад внутри окна QR-кода или «Отмена», чтобы вернуться к вводу номера телефона. Постоянного переключателя нет — это разовое действие при каждой попытке входа."
            )
        ),
        // 4. Edited Message History
        FeatureSpec(
            symbol: "clock.arrow.circlepath", color: .teal,
            title: L3(en: "Edited Message History", uz: "Tahrirlangan xabar tarixi", ru: "История правок сообщений"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Edited message history”.",
                uz: "Sozlamalar → Novagram → Chat → \"Tahrirlangan xabar tarixi\"ni yoqing.",
                ru: "Настройки → Novagram → Чат → включите «История правок сообщений»."
            ),
            works: L3(
                en: "Every time you or the other person edits a message, the previous version is saved on your device. Long-press any edited message (marked “edited”) and choose “Editing history” to see every past version in order.",
                uz: "Siz yoki suhbatdosh xabarni tahrirlaganida, oldingi versiyasi qurilmangizda saqlanadi. Tahrirlangan (\"edited\" belgili) xabarga uzoq bosib \"Tahrir tarixi\"ni tanlang — barcha versiyalarni tartib bilan ko'rasiz.",
                ru: "Каждый раз, когда вы или собеседник редактируете сообщение, предыдущая версия сохраняется на вашем устройстве. Зажмите отредактированное сообщение (с меткой «edited») и выберите «История правок» — увидите все версии по порядку."
            ),
            disable: L3(
                en: "Turn the same switch off. History already collected stays on your device, but the “Editing history” menu item stops appearing for new edits.",
                uz: "Shu switchni o'chiring. Avval yig'ilgan tarix qurilmada qoladi, lekin yangi tahrirlar uchun \"Tahrir tarixi\" menyusi ko'rinmaydi.",
                ru: "Выключите тот же переключатель. Уже собранная история останется на устройстве, но пункт «История правок» перестанет появляться для новых правок."
            )
        ),
        // 5. Voice → Text (STT)
        FeatureSpec(
            symbol: "mic.fill", color: .red,
            title: L3(en: "Voice → Text", uz: "Ovoz → Matn", ru: "Голос → Текст"),
            enable: L3(
                en: "Settings → Novagram → Voice → Text → turn on “Voice to text”. Optionally pick your “Recognition language” right below it.",
                uz: "Sozlamalar → Novagram → Ovoz → Matn → \"Ovozni matnga o'girish\"ni yoqing. Xohlasangiz, pastdagi \"Tanish tili\"ni tanlang.",
                ru: "Настройки → Novagram → Голос → Текст → включите «Голос в текст». При желании выберите «Язык распознавания» ниже."
            ),
            works: L3(
                en: "A small STT shortcut appears next to the microphone button in every chat. Tap it while recording, or after sending a voice message, to transcribe the speech to text directly on your device.",
                uz: "Har bir chatda mikrofon tugmasi yonida kichik STT tugmasi paydo bo'ladi. Ovozli xabar yozayotganda yoki yuborgandan keyin uni bosing — nutq qurilmangizda matnga aylanadi.",
                ru: "Рядом с кнопкой микрофона в каждом чате появляется маленькая кнопка STT. Нажмите её во время записи или после отправки голосового — речь распознается в текст прямо на устройстве."
            ),
            disable: L3(
                en: "Turn the same switch off. The STT shortcut disappears from the chat input area.",
                uz: "Shu switchni o'chiring. STT tugmasi chat yozish maydonidan yo'qoladi.",
                ru: "Выключите тот же переключатель. Кнопка STT исчезнет из области ввода чата."
            )
        ),
        // 6. Chat Lock (per-chat PIN)
        FeatureSpec(
            symbol: "lock.shield.fill", color: .green,
            title: L3(en: "Chat Lock (PIN)", uz: "Chat qulfi (PIN)", ru: "Блокировка чатов (PIN)"),
            enable: L3(
                en: "Long-press any chat → “Set Lock” from the context menu, then set a 4-digit PIN or a password of any length. (Settings → Novagram → Protection also has a “Chat Lock” master toggle that must be on the first time.)",
                uz: "Istalgan chatni uzoq bosing → context menyudan \"Qulf o'rnatish\"ni tanlang, so'ng 4 xonali PIN yoki istalgan uzunlikdagi parol kiriting. (Sozlamalar → Novagram → Himoya bo'limida ham \"Chat qulfi\" asosiy switchi birinchi marta yoqilgan bo'lishi kerak.)",
                ru: "Зажмите любой чат → выберите «Установить замок» в контекстном меню, затем задайте 4-значный PIN или пароль любой длины. (В Настройки → Novagram → Защита также есть главный переключатель «Блокировка чата», который должен быть включён в первый раз.)"
            ),
            works: L3(
                en: "The locked chat requires your PIN/password (or Face ID / Touch ID, if your device supports it and you enabled biometric unlock) to open. Credentials are stored securely in the iOS Keychain, never on any server.",
                uz: "Qulflangan chatni ochish uchun PIN/parol (yoki qurilmangiz qo'llab-quvvatlasa va yoqsangiz Face ID/Touch ID) so'raladi. Ma'lumotlar xavfsiz iOS Keychain'da saqlanadi, hech qanday serverga yuborilmaydi.",
                ru: "Для открытия заблокированного чата требуется PIN/пароль (или Face ID/Touch ID, если устройство поддерживает и вы включили биометрию). Данные хранятся в защищённом iOS Keychain и никогда не отправляются на сервер."
            ),
            disable: L3(
                en: "Long-press the locked chat → “Remove Lock”, and confirm with your PIN/password. Locking is per-chat, so removing it from one chat doesn't affect the others.",
                uz: "Qulflangan chatni uzoq bosing → \"Qulfni olib tashlash\", va PIN/parol bilan tasdiqlang. Qulf har bir chat uchun alohida, shuning uchun bittasidan olib tashlash boshqalariga ta'sir qilmaydi.",
                ru: "Зажмите заблокированный чат → «Снять замок» и подтвердите PIN/паролем. Блокировка отдельная для каждого чата, поэтому снятие с одного не влияет на остальные."
            )
        ),
        // 7. Secret Vault
        FeatureSpec(
            symbol: "eye.slash.fill", color: .purple,
            title: L3(en: "Hidden Chats", uz: "Yashirin chatlar", ru: "Скрытые чаты"),
            enable: L3(
                en: "Long-press any chat and choose “Hide” — the first time, you'll be asked to set a separate passcode. Or turn the toggle on directly in Settings → Novagram → Protection → “Hidden Chats”.",
                uz: "Istalgan chatni uzoq bosib \"Berkitish\"ni tanlang — birinchi marta alohida kod-parol o'rnatishingiz so'raladi. Yoki to'g'ridan-to'g'ri Sozlamalar → Novagram → Himoya → \"Yashirin chatlar\" switchini yoqing.",
                ru: "Зажмите любой чат и выберите «Скрыть» — в первый раз попросят задать отдельный код-пароль. Либо включите переключатель напрямую в Настройки → Novagram → Защита → «Скрытые чаты»."
            ),
            works: L3(
                en: "Hidden chats vanish from your main chat list and are muted automatically. To open them, long-press the “Chats” title and enter your passcode — a separate passcode from Chat Lock.",
                uz: "Berkitilgan chatlar asosiy chat ro'yxatidan yo'qoladi va avtomatik ovozsiz qilinadi. Ularni ochish uchun \"Chats\" sarlavhasini uzoq bosing va kod-parolni kiriting — bu Chat qulfidan alohida kod-parol.",
                ru: "Скрытые чаты исчезают из основного списка и автоматически отключаются от звука. Чтобы открыть их, зажмите заголовок «Chats» и введите код-пароль — он отдельный от блокировки чата."
            ),
            disable: L3(
                en: "Turn the “Hidden Chats” switch off in Settings → Novagram → Protection. This requires your Chat Lock master PIN and shows a confirmation — turning it off returns every hidden chat to the main list, unmutes them, and deletes the passcode.",
                uz: "Sozlamalar → Novagram → Himoya bo'limida \"Yashirin chatlar\" switchini o'chiring. Buning uchun Chat qulfi asosiy PIN'i kerak va tasdiqlash so'raladi — o'chirilganda barcha berkitilgan chatlar asosiy ro'yxatga qaytadi, ovozi yoqiladi va kod-parol o'chadi.",
                ru: "Выключите переключатель «Скрытые чаты» в Настройки → Novagram → Защита. Потребуется главный PIN блокировки чата и подтверждение — после отключения все скрытые чаты вернутся в основной список, звук включится, а код-пароль удалится."
            )
        ),
        // 8. Auto-Text Suffix
        FeatureSpec(
            symbol: "text.append", color: .orange,
            title: L3(en: "Auto-Text Suffix", uz: "Avto-matn qo'shimchasi", ru: "Авто-постфикс"),
            enable: L3(
                en: "Settings → Novagram → Messages → “Auto-text suffix” → type the text you want and turn it on.",
                uz: "Sozlamalar → Novagram → Xabarlar → \"Avto-matn qo'shimchasi\" → xohlagan matnni kiriting va yoqing.",
                ru: "Настройки → Novagram → Сообщения → «Авто-постфикс» → введите нужный текст и включите."
            ),
            works: L3(
                en: "The text you configured (a signature, hashtag, or anything else) is appended automatically to the end of every outgoing message you send, in every chat.",
                uz: "Siz o'rnatgan matn (imzo, hashtag yoki xohlagan narsa) har bir chiquvchi xabaringiz oxiriga, barcha chatlarda avtomatik qo'shiladi.",
                ru: "Настроенный вами текст (подпись, хэштег или что угодно) автоматически добавляется в конец каждого исходящего сообщения во всех чатах."
            ),
            disable: L3(
                en: "Open the same “Auto-text suffix” screen and turn it off, or clear the text field.",
                uz: "Xuddi shu \"Avto-matn qo'shimchasi\" ekranini oching va o'chiring yoki matn maydonini tozalang.",
                ru: "Откройте тот же экран «Авто-постфикс» и выключите, либо очистите текстовое поле."
            )
        ),
        // 9. Auto-Translate & Translate Button
        FeatureSpec(
            symbol: "character.bubble.fill", color: .pink,
            title: L3(en: "Auto-Text & Translation", uz: "Avto-matn va tarjima", ru: "Авто-текст и перевод"),
            enable: L3(
                en: "Settings → Novagram → Messages → turn on “Translate button” (adds “Translate” to the message context menu) and/or configure “Auto-translate” with your target language.",
                uz: "Sozlamalar → Novagram → Xabarlar → \"Tarjima tugmasi\"ni yoqing (xabar menyusiga \"Translate\" qo'shiladi) va/yoki \"Avto-tarjima\"ni maqsad til bilan sozlang.",
                ru: "Настройки → Novagram → Сообщения → включите «Кнопка перевода» (добавляет «Перевести» в меню сообщения) и/или настройте «Авто-перевод» с целевым языком."
            ),
            works: L3(
                en: "Long-press any incoming message and tap “Translate” to see it in your chosen language instantly, without leaving the chat. With auto-translate configured, this happens with one tap and no extra menu.",
                uz: "Istalgan kelgan xabarga uzoq bosib \"Translate\"ni bosing — u chatdan chiqmasdan tanlangan tilingizda darhol ko'rinadi. Avto-tarjima sozlangan bo'lsa, bu bir teginishda, qo'shimcha menyusiz sodir bo'ladi.",
                ru: "Зажмите любое входящее сообщение и нажмите «Перевести» — увидите его на выбранном языке мгновенно, не покидая чат. При настроенном авто-переводе это происходит одним нажатием, без лишнего меню."
            ),
            disable: L3(
                en: "Turn “Translate button” off in the same screen to remove the context-menu entry, or clear the auto-translate language to stop automatic translation.",
                uz: "Kontekst menyu bandini olib tashlash uchun shu ekranda \"Tarjima tugmasi\"ni o'chiring, yoki avtomatik tarjimani to'xtatish uchun avto-tarjima tilini tozalang.",
                ru: "Выключите «Кнопка перевода» на том же экране, чтобы убрать пункт из контекстного меню, или очистите язык авто-перевода, чтобы остановить автоматический перевод."
            )
        ),
        // 10. Unread Message Reminder
        FeatureSpec(
            symbol: "bell.badge.fill", color: .orange,
            title: L3(en: "Unread Message Reminder", uz: "Xabar eslatmasi", ru: "Напоминание о сообщении"),
            enable: L3(
                en: "Settings → Novagram → Message reminder → turn on “Unread message reminder”, then pick a “Reminder time” and “Reminder sound”.",
                uz: "Sozlamalar → Novagram → Xabar eslatmasi → \"O'qilmagan xabar eslatmasi\"ni yoqing, so'ng \"Eslatma vaqti\" va \"Eslatma ovozi\"ni tanlang.",
                ru: "Настройки → Novagram → Напоминание о сообщении → включите «Напоминание о непрочитанном», затем выберите «Время напоминания» и «Звук напоминания»."
            ),
            works: L3(
                en: "When the app is in the background and a message stays unread for your configured time, Novagram shows a local reminder notification with your chosen sound, so you never forget to reply.",
                uz: "Ilova fonda bo'lganda va xabar siz belgilagan vaqt davomida o'qilmasa, Novagram tanlangan ovoz bilan mahalliy eslatma bildirishnomasini ko'rsatadi — javob berishni unutmaysiz.",
                ru: "Когда приложение в фоне и сообщение остаётся непрочитанным заданное вами время, Novagram показывает локальное уведомление-напоминание с выбранным звуком — вы не забудете ответить."
            ),
            disable: L3(
                en: "Turn the same “Unread message reminder” switch off. No more reminder notifications will be scheduled.",
                uz: "Xuddi shu \"O'qilmagan xabar eslatmasi\" switchini o'chiring. Endi eslatma bildirishnomalari rejalashtirilmaydi.",
                ru: "Выключите тот же переключатель «Напоминание о непрочитанном». Новые уведомления-напоминания больше не будут запланированы."
            )
        ),
        // 11. Recommended Folders
        FeatureSpec(
            symbol: "folder.badge.plus", color: .blue,
            title: L3(en: "Recommended Folders", uz: "Tavsiya etilgan papkalar", ru: "Рекомендуемые папки"),
            enable: L3(
                en: "Settings → Novagram → Features → tap “Recommended folders” (or accept the one-time prompt shown on first launch).",
                uz: "Sozlamalar → Novagram → Imkoniyatlar → \"Tavsiya etilgan papkalar\"ni bosing (yoki birinchi ishga tushirishda chiqadigan bir martalik taklifni qabul qiling).",
                ru: "Настройки → Novagram → Функции → нажмите «Рекомендуемые папки» (или примите разовое предложение при первом запуске)."
            ),
            works: L3(
                en: "One tap instantly creates four ready-made chat folders — Personal, Unread, Channels and Bots — so you don't have to build folders from scratch.",
                uz: "Bir bosishda darhol 4 ta tayyor chat jild yaratiladi — Shaxsiy, O'qilmagan, Kanallar va Botlar — jildlarni noldan yasashingiz shart emas.",
                ru: "Одним нажатием сразу создаются 4 готовые папки чатов — Личные, Непрочитанные, Каналы и Боты — не нужно создавать папки с нуля."
            ),
            disable: L3(
                en: "This is a one-time action, not a persistent toggle — there's nothing to turn off. Delete any folder you don't want the normal way (Chat Folders settings → swipe or edit).",
                uz: "Bu bir martalik amal, doimiy switch emas — o'chirish uchun hech narsa yo'q. Kerak bo'lmagan jildni odatdagi tarzda o'chiring (Chat Folders sozlamalari → surish yoki tahrirlash).",
                ru: "Это разовое действие, а не постоянный переключатель — выключать нечего. Удалите ненужную папку обычным способом (настройки папок чатов → свайп или редактирование)."
            )
        ),
        // 12. Folder Display Style
        FeatureSpec(
            symbol: "square.grid.2x2.fill", color: .purple,
            title: L3(en: "Folder Display Style", uz: "Papka ko'rinishi", ru: "Стиль папок"),
            enable: L3(
                en: "Settings → Novagram → Features → “Folder display style” → choose Icons, Text, or Automatic.",
                uz: "Sozlamalar → Novagram → Imkoniyatlar → \"Papka ko'rinishi\" → Ikonkalar, Matn yoki Avtomatikni tanlang.",
                ru: "Настройки → Novagram → Функции → «Стиль папок» → выберите Иконки, Текст или Авто."
            ),
            works: L3(
                en: "Controls how folder tabs render above your chat list: “Icons” shows only the folder's emoji, “Text” shows only its name, “Automatic” follows Telegram's normal behavior. (Novagram also unlocks the Premium-only folder icon picker and folder tags for everyone — no extra toggle needed.)",
                uz: "Chat ro'yxati tepasidagi jild tablari qanday ko'rinishini boshqaradi: \"Ikonkalar\" faqat jild emojisini, \"Matn\" faqat nomini ko'rsatadi, \"Avtomatik\" Telegramning odatiy xatti-harakatiga amal qiladi. (Novagram, shuningdek, Premium-only jild ikonka tanlagichi va jild teglarini hammaga ochadi — qo'shimcha switch kerak emas.)",
                ru: "Управляет отображением вкладок папок над списком чатов: «Иконки» показывает только эмодзи папки, «Текст» — только название, «Авто» следует обычному поведению Telegram. (Novagram также открывает всем выбор иконки папки и теги папок, доступные только в Premium — без отдельного переключателя.)"
            ),
            disable: L3(
                en: "Pick “Automatic” to return to Telegram's default folder-tab behavior.",
                uz: "Telegramning standart jild-tab xatti-harakatiga qaytish uchun \"Avtomatik\"ni tanlang.",
                ru: "Выберите «Авто», чтобы вернуться к стандартному поведению вкладок папок Telegram."
            )
        ),
        // 13. Channel History Button
        FeatureSpec(
            symbol: "clock.arrow.circlepath", color: .orange,
            title: L3(en: "Channel History Button", uz: "Kanal tarixi tugmasi", ru: "Кнопка истории канала"),
            enable: L3(
                en: "Settings → Novagram → Features → turn on “Channel history button”.",
                uz: "Sozlamalar → Novagram → Imkoniyatlar → \"Kanal tarixi tugmasi\"ni yoqing.",
                ru: "Настройки → Novagram → Функции → включите «Кнопка истории канала»."
            ),
            works: L3(
                en: "Adds a “Recent actions” item to the menu of channels where you're an admin, giving you a quick shortcut to the channel's admin log.",
                uz: "Siz admin bo'lgan kanallar menyusiga \"So'nggi amallar\" bandini qo'shadi — kanal admin jurnaliga tezkor kirish imkonini beradi.",
                ru: "Добавляет пункт «Недавние действия» в меню каналов, где вы администратор — быстрый доступ к журналу администратора канала."
            ),
            disable: L3(
                en: "Turn the same switch off to remove the menu item.",
                uz: "Menyu bandini olib tashlash uchun shu switchni o'chiring.",
                ru: "Выключите тот же переключатель, чтобы убрать пункт меню."
            )
        ),
        // 14. Auto-Accept Requests
        FeatureSpec(
            symbol: "checkmark.circle.fill", color: .green,
            title: L3(en: "Auto-Accept Requests", uz: "Avto-qabul qilish", ru: "Авто-принятие запросов"),
            enable: L3(
                en: "Settings → Novagram → Features → turn on “Auto-accept requests”.",
                uz: "Sozlamalar → Novagram → Imkoniyatlar → \"Avto-qabul qilish\"ni yoqing.",
                ru: "Настройки → Novagram → Функции → включите «Авто-принятие запросов»."
            ),
            works: L3(
                en: "For groups and channels where you're an admin, pending join requests are automatically accepted in the background — no need to open the requests list and tap Accept one by one.",
                uz: "Siz admin bo'lgan guruh va kanallarda, kutilayotgan qo'shilish so'rovlari fonda avtomatik qabul qilinadi — so'rovlar ro'yxatini ochib, birma-bir Qabul qilish tugmasini bosish shart emas.",
                ru: "В группах и каналах, где вы администратор, ожидающие запросы на вступление автоматически принимаются в фоне — не нужно открывать список запросов и нажимать «Принять» по одному."
            ),
            disable: L3(
                en: "Turn the same switch off. New join requests will wait for your manual approval again.",
                uz: "Shu switchni o'chiring. Yangi qo'shilish so'rovlari yana qo'lda tasdiqlashingizni kutadi.",
                ru: "Выключите тот же переключатель. Новые запросы на вступление снова будут ждать вашего ручного подтверждения."
            )
        ),
        // 15. Forward Without Name
        FeatureSpec(
            symbol: "arrowshape.turn.up.right.circle.fill", color: .green,
            title: L3(en: "Forward Without Name", uz: "Imzosiz forward", ru: "Пересылка без имени"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Forward Without Name”.",
                uz: "Sozlamalar → Novagram → Chat → \"Imzosiz forward\"ni yoqing.",
                ru: "Настройки → Novagram → Чат → включите «Пересылка без имени»."
            ),
            works: L3(
                en: "Adds a “Forward without name” item to the message action menu. Choosing it forwards the message without the “Forwarded from …” attribution, hiding the original sender's name.",
                uz: "Xabar amallar menyusiga \"Imzosiz forward qilish\" bandini qo'shadi. Uni tanlasangiz, xabar \"Forwarded from …\" imzosisiz forward qilinadi va asl yuboruvchi nomi berkitiladi.",
                ru: "Добавляет пункт «Переслать без имени» в меню действий с сообщением. При выборе сообщение пересылается без пометки «Переслано от …», скрывая имя исходного отправителя."
            ),
            disable: L3(
                en: "Turn the same switch off to remove the menu item — forwarding goes back to showing the original sender's name.",
                uz: "Menyu bandini olib tashlash uchun shu switchni o'chiring — forward qilish yana asl yuboruvchi nomini ko'rsatadi.",
                ru: "Выключите тот же переключатель, чтобы убрать пункт меню — пересылка снова будет показывать имя исходного отправителя."
            )
        ),
        // 16. Novagram Bots
        FeatureSpec(
            symbol: "bolt.circle.fill", color: .teal,
            title: L3(en: "Novagram Bots", uz: "Novagram Botlar", ru: "Боты Novagram"),
            enable: L3(
                en: "No toggle needed — open Settings → Novagram and tap the “Novagram Bots” row near the top.",
                uz: "Switch kerak emas — Sozlamalar → Novagram'ni oching va yuqoridagi \"Novagram Botlar\" qatorini bosing.",
                ru: "Переключатель не нужен — откройте Настройки → Novagram и нажмите строку «Боты Novagram» в верхней части списка."
            ),
            works: L3(
                en: "Shows a curated, categorized directory of useful Telegram bots (utilities, downloaders, tools, etc.) with a short description for each — tap any bot to open a chat with it directly.",
                uz: "Foydali Telegram botlarining tartiblangan, toifalarga bo'lingan ro'yxatini har biri uchun qisqa tavsif bilan ko'rsatadi — istalgan botni bosib, u bilan chatni to'g'ridan-to'g'ri oching.",
                ru: "Показывает подобранный, разделённый по категориям каталог полезных Telegram-ботов (утилиты, загрузчики, инструменты и т.д.) с кратким описанием каждого — нажмите на любого бота, чтобы открыть чат с ним напрямую."
            ),
            disable: L3(
                en: "This is a read-only directory screen, not a feature toggle — simply don't open it if you don't need it.",
                uz: "Bu faqat o'qish uchun katalog ekrani, feature switch emas — kerak bo'lmasa, uni ochmasangiz bo'ldi.",
                ru: "Это экран-каталог только для просмотра, а не переключаемая функция — просто не открывайте его, если не нужно."
            )
        ),
        // 17. Unlimited Pins
        FeatureSpec(
            symbol: "pin.circle.fill", color: .orange,
            title: L3(en: "Unlimited Pins", uz: "Cheksiz pin", ru: "Безлимитные закрепы"),
            enable: L3(
                en: "Settings → Novagram → Interface → turn on “Unlimited Pins”.",
                uz: "Sozlamalar → Novagram → Interfeys → \"Cheksiz pin\"ni yoqing.",
                ru: "Настройки → Novagram → Интерфейс → включите «Безлимитные закрепы»."
            ),
            works: L3(
                en: "Lets you pin more than Telegram's standard 5-chat limit at the top of your chat list. Extra pins beyond the limit are kept locally on this device.",
                uz: "Chat ro'yxati tepasida Telegramning standart 5 ta chegarasidan ko'proq chatni pin qilish imkonini beradi. Chegaradan ortiq pinlar shu qurilmada saqlanadi.",
                ru: "Позволяет закреплять больше чатов вверху списка, чем стандартный лимит Telegram в 5 штук. Закрепы сверх лимита сохраняются локально на этом устройстве."
            ),
            disable: L3(
                en: "Turn the same switch off. Any pins beyond the 5-chat limit stop showing (server-side pin order is untouched, so nothing is lost).",
                uz: "Shu switchni o'chiring. 5 ta chegaradan ortiq pinlar ko'rinishdan to'xtaydi (server tarafidagi pin tartibi o'zgarmaydi, hech narsa yo'qolmaydi).",
                ru: "Выключите тот же переключатель. Закрепы сверх лимита в 5 чатов перестанут отображаться (порядок закрепления на сервере не меняется, ничего не потеряется)."
            )
        ),
        // 18. Novagram Proxy (auto-proxy)
        FeatureSpec(
            symbol: "lock.shield", color: .green,
            title: L3(en: "Novagram Proxy", uz: "NovagramProxy", ru: "NovagramProxy"),
            enable: L3(
                en: "Settings → Novagram → Protection → turn on “Enable NovagramProxy”.",
                uz: "Sozlamalar → Novagram → Himoya → \"NovagramProxy'ni yoqish\"ni yoqing.",
                ru: "Настройки → Novagram → Защита → включите «Включить NovagramProxy»."
            ),
            works: L3(
                en: "Automatically connects through a SOCKS5 proxy when Telegram is blocked in your country, using a rotating pool of proxy servers — no manual proxy address needed.",
                uz: "Telegram sizning davlatingizda bloklangan bo'lsa, avtomatik SOCKS5 proksi orqali ulanadi — aylanma proksi serverlar to'plamidan foydalaniladi, qo'lda manzil kiritish shart emas.",
                ru: "Автоматически подключается через SOCKS5-прокси, если Telegram заблокирован в вашей стране, используя ротацию пула прокси-серверов — вручную вводить адрес не нужно."
            ),
            disable: L3(
                en: "Turn the same switch off to connect directly again (default state — off).",
                uz: "To'g'ridan-to'g'ri qayta ulanish uchun shu switchni o'chiring (standart holat — o'chiq).",
                ru: "Выключите тот же переключатель, чтобы снова подключаться напрямую (состояние по умолчанию — выключено)."
            )
        ),
        // 19. Block Foreign Numbers
        FeatureSpec(
            symbol: "person.crop.circle.badge.xmark", color: .orange,
            title: L3(en: "Block Foreign Numbers", uz: "Xorijiy raqamlarni bloklash", ru: "Блокировка иностранных номеров"),
            enable: L3(
                en: "Settings → Novagram → Protection → turn on “Block foreign numbers”.",
                uz: "Sozlamalar → Novagram → Himoya → \"Xorijiy raqamlarni bloklash\"ni yoqing.",
                ru: "Настройки → Novagram → Защита → включите «Блокировать иностранные номера»."
            ),
            works: L3(
                en: "Incoming messages from phone numbers registered in other countries are blocked automatically, as basic protection against foreign spam accounts.",
                uz: "Boshqa davlatlarda ro'yxatdan o'tgan telefon raqamlaridan kelgan xabarlar avtomatik bloklanadi — xorijiy spam akkauntlaridan asosiy himoya sifatida.",
                ru: "Входящие сообщения с номеров телефонов, зарегистрированных в других странах, блокируются автоматически — как базовая защита от иностранных спам-аккаунтов."
            ),
            disable: L3(
                en: "Turn the same switch off. Messages from any country are allowed through again.",
                uz: "Shu switchni o'chiring. Istalgan davlatdan xabarlar yana o'tadi.",
                ru: "Выключите тот же переключатель. Сообщения из любой страны снова будут проходить."
            )
        ),
        // 20. Folder premium unlocks (always-on)
        FeatureSpec(
            symbol: "folder.fill", color: .blue,
            title: L3(en: "Unlimited Folders & Tags", uz: "Cheksiz jildlar va teglar", ru: "Безлимитные папки и теги"),
            enable: L3(
                en: "Nothing to turn on — this runs automatically for every Novagram user, no Premium subscription required.",
                uz: "Yoqish shart emas — bu har bir Novagram foydalanuvchisi uchun avtomatik ishlaydi, Premium obuna kerak emas.",
                ru: "Включать не нужно — это работает автоматически для каждого пользователя Novagram, Premium-подписка не требуется."
            ),
            works: L3(
                en: "Removes Telegram's Premium-only folder-count cap (create far more than the free limit) and unlocks the “Show Folder Tags” option — a small label under each chat naming which folder it belongs to — for everyone, not just Premium subscribers.",
                uz: "Telegramning Premium-only jild soni chegarasini olib tashlaydi (bepul limitdan ancha ko'p jild yaratish mumkin) va \"Jild teglarini ko'rsatish\" — har bir chat ostida u qaysi jildga tegishli ekanini ko'rsatuvchi kichik yorliq — imkoniyatini hammaga, faqat Premium obunachilarga emas, ochadi.",
                ru: "Убирает ограничение Telegram Premium на количество папок (можно создать намного больше бесплатного лимита) и открывает опцию «Показывать теги папок» — небольшую метку под каждым чатом, указывающую его папку — для всех, а не только для подписчиков Premium."
            ),
            disable: L3(
                en: "This is a permanent client-side unlock, not a toggle — folder tags can still be turned off per-folder from Telegram's own folder editor if you don't want the label showing.",
                uz: "Bu doimiy client-tarafidagi ochish, switch emas — agar yorliq ko'rinishini xohlamasangiz, jild teglarini Telegramning o'z jild muharriridan har bir jild uchun alohida o'chirishingiz mumkin.",
                ru: "Это постоянная клиентская разблокировка, а не переключатель — теги папок всё же можно отключить для каждой папки отдельно в собственном редакторе папок Telegram, если не хотите видеть метку."
            )
        ),
        // 21. Round Video from Gallery
        FeatureSpec(
            symbol: "video.circle.fill", color: .blue,
            title: L3(en: "Round Video from Gallery", uz: "Galereyadan dumaloq video", ru: "Круглое видео из галереи"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Round video from gallery”.",
                uz: "Sozlamalar → Novagram → Chat → \"Galereyadan dumaloq video\"ni yoqing.",
                ru: "Настройки → Novagram → Чат → включите «Круглое видео из галереи»."
            ),
            works: L3(
                en: "Adds a “Photos” option to the round video-message camera menu, so you can pick any existing video from your gallery and send it as a round video message — not just freshly recorded ones.",
                uz: "Dumaloq video-xabar kamera menyusiga \"Galereya\" bandini qo'shadi — endi faqat yangi yozib olingan emas, galereyangizdagi istalgan videoni tanlab, dumaloq video xabar sifatida yuborishingiz mumkin.",
                ru: "Добавляет пункт «Галерея» в меню камеры круглого видео-сообщения — теперь можно выбрать любое видео из галереи и отправить его как круглое видео-сообщение, а не только только что записанное."
            ),
            disable: L3(
                en: "Turn the same switch off to remove the “Photos” option from that menu.",
                uz: "Shu menyudan \"Galereya\" bandini olib tashlash uchun switchni o'chiring.",
                ru: "Выключите тот же переключатель, чтобы убрать пункт «Галерея» из этого меню."
            )
        ),
        // 22. Deleted Messages Marker
        FeatureSpec(
            symbol: "trash.slash.fill", color: .red,
            title: L3(en: "Deleted Messages Marker", uz: "O'chirilgan xabarlar", ru: "Метка удалённых сообщений"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Deleted messages”.",
                uz: "Sozlamalar → Novagram → Chat → \"O'chirilgan xabarlar\"ni yoqing.",
                ru: "Настройки → Novagram → Чат → включите «Удалённые сообщения»."
            ),
            works: L3(
                en: "When someone deletes a message you've already seen, it stays visible in the chat with a small 🗑 marker instead of disappearing, so you can still tell something was removed.",
                uz: "Kimdir siz allaqachon ko'rgan xabarni o'chirsa, u chatdan yo'qolmasdan kichik 🗑 belgisi bilan ko'rinib turadi — shunda xabar o'chirilganini bilib turasiz.",
                ru: "Когда кто-то удаляет уже просмотренное вами сообщение, оно остаётся видимым в чате с маленькой меткой 🗑 вместо исчезновения — вы всё равно поймёте, что что-то удалили."
            ),
            disable: L3(
                en: "Turn the same switch off. Deleted messages disappear immediately again, like standard Telegram.",
                uz: "Shu switchni o'chiring. O'chirilgan xabarlar yana darhol yo'qoladi, odatdagi Telegramdek.",
                ru: "Выключите тот же переключатель. Удалённые сообщения снова будут исчезать сразу, как в обычном Telegram."
            )
        ),
        // 23. View First Message
        FeatureSpec(
            symbol: "arrow.up.to.line", color: .blue,
            title: L3(en: "Jump to First Message", uz: "Birinchi xabarga o'tish", ru: "К первому сообщению"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Jump to first message”.",
                uz: "Sozlamalar → Novagram → Chat → \"Birinchi xabarga o'tish\"ni yoqing.",
                ru: "Настройки → Novagram → Чат → включите «К первому сообщению»."
            ),
            works: L3(
                en: "Adds a “View First Message” entry to any chat's profile menu, letting you jump straight to the very first message ever exchanged in that chat, no matter how long the history is.",
                uz: "Istalgan chat profil menyusiga \"View First Message\" bandini qo'shadi — chat tarixi qanchalik uzun bo'lmasin, shu chatdagi eng birinchi xabarga to'g'ridan-to'g'ri o'tishingiz mumkin.",
                ru: "Добавляет пункт «View First Message» в меню профиля любого чата — можно сразу перейти к самому первому сообщению в этом чате, независимо от длины истории."
            ),
            disable: L3(
                en: "Turn the same switch off to remove the menu item.",
                uz: "Menyu bandini olib tashlash uchun shu switchni o'chiring.",
                ru: "Выключите тот же переключатель, чтобы убрать пункт меню."
            )
        ),
        // 24. Camera Picker (long-press)
        FeatureSpec(
            symbol: "camera.rotate.fill", color: .orange,
            title: L3(en: "Camera Picker", uz: "Kamerani tanlash", ru: "Выбор камеры"),
            enable: L3(
                en: "Settings → Novagram → Chat → turn on “Camera picker”.",
                uz: "Sozlamalar → Novagram → Chat → \"Kamerani tanlash\"ni yoqing.",
                ru: "Настройки → Novagram → Чат → включите «Выбор камеры»."
            ),
            works: L3(
                en: "Long-press the video-message (circular camera) button in a chat to quickly switch between the front and back camera before recording, instead of only being able to flip mid-recording.",
                uz: "Video-xabar (dumaloq kamera) tugmasini uzun bosib, yozishni boshlashdan oldin old/orqa kamerani tezkor almashtirishingiz mumkin — faqat yozish jarayonida emas.",
                ru: "Зажмите кнопку видео-сообщения (круглая камера) в чате, чтобы быстро переключиться между передней и задней камерой перед записью, а не только во время неё."
            ),
            disable: L3(
                en: "Turn the same switch off. Long-press stops offering the camera-selection menu.",
                uz: "Shu switchni o'chiring. Uzoq bosish kamera tanlash menyusini taklif qilmaydi.",
                ru: "Выключите тот же переключатель. Долгое нажатие перестанет предлагать меню выбора камеры."
            )
        ),
        // 25. Mutual Contact Badge
        FeatureSpec(
            symbol: "person.2.fill", color: .lightBlue,
            title: L3(en: "Mutual Contact Badge", uz: "Mutual kontakt belgisi", ru: "Значок взаимного контакта"),
            enable: L3(
                en: "Settings → Novagram → Interface → turn on “Mutual contact badge”.",
                uz: "Sozlamalar → Novagram → Interfeys → \"Mutual kontakt belgisi\"ni yoqing.",
                ru: "Настройки → Novagram → Интерфейс → включите «Значок взаимного контакта»."
            ),
            works: L3(
                en: "Shows a small 🤝 badge next to contacts who have you saved in their own contacts too, so you can spot mutual contacts at a glance in your contacts list.",
                uz: "Sizni ham o'z kontaktiga saqlagan kontaktlar yonida kichik 🤝 belgisini ko'rsatadi — kontaktlar ro'yxatida mutual kontaktlarni bir qarashda ko'rasiz.",
                ru: "Показывает маленький значок 🤝 рядом с контактами, у которых вы тоже сохранены в контактах — вы сразу увидите взаимные контакты в списке."
            ),
            disable: L3(
                en: "Turn the same switch off. The badge disappears from your contacts list.",
                uz: "Shu switchni o'chiring. Belgi kontaktlar ro'yxatidan yo'qoladi.",
                ru: "Выключите тот же переключатель. Значок исчезнет из списка контактов."
            )
        ),
        // 26. Stories Panel Toggle
        FeatureSpec(
            symbol: "circle.dashed", color: .violet,
            title: L3(en: "Stories Panel", uz: "Hikoyalar paneli", ru: "Панель историй"),
            enable: L3(
                en: "Settings → Novagram → Interface → turn “Stories panel” on or off (on by default).",
                uz: "Sozlamalar → Novagram → Interfeys → \"Hikoyalar paneli\"ni yoqing yoki o'chiring (standart holatda yoqilgan).",
                ru: "Настройки → Novagram → Интерфейс → включите или выключите «Панель историй» (по умолчанию включено)."
            ),
            works: L3(
                en: "Controls whether the row of story avatars appears above your chat list, exactly like Telegram's own Stories bar.",
                uz: "Chat ro'yxati tepasida hikoya avatarlari qatori chiqishi yoki chiqmasligini boshqaradi — Telegramning o'z Hikoyalar paneliga o'xshab.",
                ru: "Управляет тем, отображается ли ряд аватаров историй над списком чатов — так же, как собственная панель историй Telegram."
            ),
            disable: L3(
                en: "Turn the switch off to hide the stories panel and reclaim that space at the top of the chat list.",
                uz: "Hikoyalar panelini yashirish va chat ro'yxati tepasidagi joyni bo'shatish uchun switchni o'chiring.",
                ru: "Выключите переключатель, чтобы скрыть панель историй и освободить место вверху списка чатов."
            )
        ),
        // 27. Hide Folders Toggle
        FeatureSpec(
            symbol: "folder.badge.minus", color: .lightBlue,
            title: L3(en: "Hide Folders", uz: "Jildlarni yashirish", ru: "Скрыть папки"),
            enable: L3(
                en: "Settings → Novagram → Interface → turn on “Hide folders”.",
                uz: "Sozlamalar → Novagram → Interfeys → \"Jildlarni yashirish\"ni yoqing.",
                ru: "Настройки → Novagram → Интерфейс → включите «Скрыть папки»."
            ),
            works: L3(
                en: "Temporarily hides the folder tabs row above your chat list — useful when you want a cleaner, distraction-free chat list for a while.",
                uz: "Chat ro'yxati tepasidagi jild tablari qatorini vaqtinchalik yashiradi — chat ro'yxatini biroz toza va chalg'itmaydigan holatda ko'rmoqchi bo'lganda foydali.",
                ru: "Временно скрывает ряд вкладок папок над списком чатов — полезно, когда хочется на время получить более чистый список без отвлекающих факторов."
            ),
            disable: L3(
                en: "Turn the switch off to bring the folder tabs back.",
                uz: "Jild tablarini qaytarish uchun switchni o'chiring.",
                ru: "Выключите переключатель, чтобы вернуть вкладки папок."
            )
        ),
        // 28. White Theme Accent
        FeatureSpec(
            symbol: "paintpalette.fill", color: .green,
            title: L3(en: "White Theme Accent", uz: "Oq tema aksenti", ru: "Акцент светлой темы"),
            enable: L3(
                en: "Settings → Novagram → Appearance → turn on the accent-color toggle.",
                uz: "Sozlamalar → Novagram → Ko'rinish → aksent rang switchini yoqing.",
                ru: "Настройки → Novagram → Внешний вид → включите переключатель акцентного цвета."
            ),
            works: L3(
                en: "Adjusts the accent color used across the interface when the light (white) theme is active, for a cleaner look tuned to Novagram's branding.",
                uz: "Yorug' (oq) tema faol bo'lganda interfeysda ishlatiladigan aksent rangni sozlaydi — Novagram brendiga moslashtirilgan, tozaroq ko'rinish uchun.",
                ru: "Настраивает акцентный цвет интерфейса при активной светлой (белой) теме — для более чистого вида, адаптированного под брендинг Novagram."
            ),
            disable: L3(
                en: "Turn the switch off to return to Telegram's standard light-theme accent color.",
                uz: "Telegramning standart yorug' tema aksent rangiga qaytish uchun switchni o'chiring.",
                ru: "Выключите переключатель, чтобы вернуться к стандартному акцентному цвету светлой темы Telegram."
            )
        ),
        // 29. Heart Effect
        FeatureSpec(
            symbol: "heart.fill", color: .red,
            title: L3(en: "Heart Effect", uz: "Yurakcha effekti", ru: "Эффект сердечка"),
            enable: L3(
                en: "Settings → Novagram → Messages → turn on “Heart effect”.",
                uz: "Sozlamalar → Novagram → Xabarlar → \"Yurakcha effekti\"ni yoqing.",
                ru: "Настройки → Novagram → Сообщения → включите «Эффект сердечка»."
            ),
            works: L3(
                en: "Automatically attaches the animated ❤️ message effect to every text message you send — a small, playful touch with no extra taps.",
                uz: "Yuboradigan har bir matnli xabaringizga animatsion ❤️ effektini avtomatik qo'shadi — qo'shimcha bosishlarsiz kichik, quvnoq teginish.",
                ru: "Автоматически добавляет анимированный эффект ❤️ к каждому отправленному текстовому сообщению — небольшой игривый штрих без лишних нажатий."
            ),
            disable: L3(
                en: "Turn the same switch off to send plain messages again, with no automatic effect.",
                uz: "Oddiy, hech qanday avtomatik effektsiz xabar yuborish uchun shu switchni o'chiring.",
                ru: "Выключите тот же переключатель, чтобы снова отправлять обычные сообщения без автоматического эффекта."
            )
        ),
        // 30. Auto Sticker
        FeatureSpec(
            symbol: "face.smiling.inverse", color: .orange,
            title: L3(en: "Auto Sticker", uz: "Avtomatik sticker", ru: "Авто-стикер"),
            enable: L3(
                en: "Settings → Novagram → Messages → turn on “Auto sticker”.",
                uz: "Sozlamalar → Novagram → Xabarlar → \"Avtomatik sticker\"ni yoqing.",
                ru: "Настройки → Novagram → Сообщения → включите «Авто-стикер»."
            ),
            works: L3(
                en: "After every text message you send, Novagram automatically appends the last sticker you sent — handy if you like following up messages with the same reaction sticker.",
                uz: "Yuborgan har bir matnli xabaringizdan so'ng, Novagram avtomatik ravishda oxirgi yuborgan stickeringizni qo'shadi — bir xil reaksiya stickeri bilan xabar davom ettirishni yoqtirsangiz qulay.",
                ru: "После каждого отправленного текстового сообщения Novagram автоматически добавляет последний отправленный вами стикер — удобно, если вы любите сопровождать сообщения одним и тем же стикером-реакцией."
            ),
            disable: L3(
                en: "Turn the same switch off. Text messages are sent alone again, without an extra sticker.",
                uz: "Shu switchni o'chiring. Matnli xabarlar yana yolg'iz, qo'shimcha stickersiz yuboriladi.",
                ru: "Выключите тот же переключатель. Текстовые сообщения снова будут отправляться без дополнительного стикера."
            )
        ),
        // 31. Ask Before Sending
        FeatureSpec(
            symbol: "hand.raised.fill", color: .purple,
            title: L3(en: "Ask Before Sending", uz: "Yuborishdan oldin so'rash", ru: "Спрашивать перед отправкой"),
            enable: L3(
                en: "Settings → Novagram → Protection → turn on “Ask before sending”.",
                uz: "Sozlamalar → Novagram → Himoya → \"Yuborishdan oldin so'rash\"ni yoqing.",
                ru: "Настройки → Novagram → Защита → включите «Спрашивать перед отправкой»."
            ),
            works: L3(
                en: "Shows a small confirmation dialog before sending a voice message, sticker, or gift, helping you avoid accidental sends from a stray tap.",
                uz: "Ovozli xabar, stiker yoki sovg'a yuborishdan oldin kichik tasdiqlash dialogini ko'rsatadi — tasodifiy bosishdan kelib chiqqan xato yuborishlarning oldini oladi.",
                ru: "Показывает небольшой диалог подтверждения перед отправкой голосового сообщения, стикера или подарка — помогает избежать случайной отправки от неловкого нажатия."
            ),
            disable: L3(
                en: "Turn the same switch off. Those message types send immediately again, with no confirmation step.",
                uz: "Shu switchni o'chiring. Bu turdagi xabarlar yana darhol, tasdiqlashsiz yuboriladi.",
                ru: "Выключите тот же переключатель. Эти типы сообщений снова будут отправляться сразу, без подтверждения."
            )
        ),
        // 32. Ask to Translate on Send
        FeatureSpec(
            symbol: "questionmark.bubble.fill", color: .orange,
            title: L3(en: "Ask to Translate on Send", uz: "Yuborishda tarjima so'rovi", ru: "Запрос перевода при отправке"),
            enable: L3(
                en: "Settings → Novagram → Messages → turn on “Ask to translate on send”. (This is mutually exclusive with the Voice → Text “Translate voice messages” auto-translate — enabling one turns off the other.)",
                uz: "Sozlamalar → Novagram → Xabarlar → \"Yuborishda tarjima so'rovi\"ni yoqing. (Bu Ovoz → Matn bo'limidagi \"Ovozli xabarlarni tarjima qilish\" avto-tarjima bilan bir-birini istisno qiladi — birini yoqish ikkinchisini o'chiradi.)",
                ru: "Настройки → Novagram → Сообщения → включите «Запрос перевода при отправке». (Это взаимоисключающая опция с авто-переводом «Переводить голосовые сообщения» в разделе Голос → Текст — включение одной выключает другую.)"
            ),
            works: L3(
                en: "Before sending a message, a dialog asks whether to send the translated version or the original — giving you a manual choice every time instead of automatic translation.",
                uz: "Xabar yuborishdan oldin, tarjima qilingan versiyani yoki asl nusxasini yuborishni so'raydigan dialog chiqadi — avtomatik tarjima o'rniga har safar qo'lda tanlov beradi.",
                ru: "Перед отправкой сообщения появляется диалог с вопросом — отправить переведённую версию или оригинал — давая вам ручной выбор каждый раз вместо автоматического перевода."
            ),
            disable: L3(
                en: "Turn the same switch off to stop the prompt from appearing before sending.",
                uz: "Yuborishdan oldin so'rovni to'xtatish uchun shu switchni o'chiring.",
                ru: "Выключите тот же переключатель, чтобы диалог перестал появляться перед отправкой."
            )
        ),
        // 33. Settings Links
        FeatureSpec(
            symbol: "link.circle.fill", color: .teal,
            title: L3(en: "Settings Links", uz: "Sozlamalar havolalari", ru: "Ссылки в настройках"),
            enable: L3(
                en: "Settings → Novagram → Features → turn on “Settings links”.",
                uz: "Sozlamalar → Novagram → Imkoniyatlar → \"Sozlamalar havolalari\"ni yoqing.",
                ru: "Настройки → Novagram → Функции → включите «Ссылки в настройках»."
            ),
            works: L3(
                en: "Reveals a “Share Novagram Settings link” row that copies and shares a tg://settings/novagrampro deep link — tapping it on any device with Novagram installed opens this settings screen directly.",
                uz: "\"Novagram Settings havolasini ulashish\" qatorini ochadi — u tg://settings/novagrampro deep linkini nusxalab, ulashadi. Novagram o'rnatilgan istalgan qurilmada uni bosish shu sozlamalar ekranini to'g'ridan-to'g'ri ochadi.",
                ru: "Открывает строку «Поделиться ссылкой Novagram Settings», которая копирует и делится deep-ссылкой tg://settings/novagrampro — нажатие на неё на любом устройстве с Novagram сразу открывает этот экран настроек."
            ),
            disable: L3(
                en: "Turn the same switch off to hide the share-link row again.",
                uz: "Ulashish havolasi qatorini yana yashirish uchun shu switchni o'chiring.",
                ru: "Выключите тот же переключатель, чтобы снова скрыть строку с ссылкой для отправки."
            )
        )
    ]
}

private func aboutFeatures(langCode: String) -> [AboutFeature] {
    return allFeatureSpecs().map { $0.asAboutFeature(langCode: langCode) }
}

// MARK: - Section ID layout
//
// Stable section IDs ensure the list renders in the correct visual order.
// Ranges are non-overlapping; each feature occupies its own section so the
// footer paragraph wraps cleanly under its row.
//
//   0          → intro
//   1 …  99    → feature sections (allFeatureSpecs() currently has 33 entries)
//   100000     → closing footer

private enum FenixAboutEntry: ItemListNodeEntry {
    case introHeader(String)
    case introBody(String)
    case featureRow(Int, AboutFeature, PresentationTheme)
    case featureBody(Int, String)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .introHeader, .introBody:
            return 0
        case let .featureRow(index, _, _), let .featureBody(index, _):
            return ItemListSectionId(1 + Int32(index))
        case .footer:
            return 100000
        }
    }

    var stableId: Int32 {
        switch self {
        case .introHeader:    return 0
        case .introBody:      return 1
        case let .featureRow(index, _, _):
            // 2 entries per feature: row then body. Slots 100, 102, 104 …
            return Int32(100 + index * 2)
        case let .featureBody(index, _):
            return Int32(100 + index * 2 + 1)
        case .footer:         return 1_000_000
        }
    }

    static func == (lhs: FenixAboutEntry, rhs: FenixAboutEntry) -> Bool {
        switch lhs {
        case let .introHeader(text):
            if case .introHeader(text) = rhs { return true }
            return false
        case let .introBody(text):
            if case .introBody(text) = rhs { return true }
            return false
        case let .featureRow(index, feature, lhsTheme):
            if case let .featureRow(rhsIndex, rhsFeature, rhsTheme) = rhs,
               index == rhsIndex,
               feature.title == rhsFeature.title,
               feature.body == rhsFeature.body,
               feature.symbol == rhsFeature.symbol,
               lhsTheme === rhsTheme { return true }
            return false
        case let .featureBody(index, text):
            if case let .featureBody(rhsIndex, rhsText) = rhs,
               index == rhsIndex, text == rhsText { return true }
            return false
        case let .footer(text):
            if case .footer(text) = rhs { return true }
            return false
        }
    }

    static func < (lhs: FenixAboutEntry, rhs: FenixAboutEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .introHeader(text):
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: text,
                sectionId: self.section
            )
        case let .introBody(text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
            )
        case let .featureRow(_, feature, _):
            // Icon + title, no chevron and no action — this is a description row.
            return ItemListDisclosureItem(
                presentationData: presentationData,
                icon: fenixuzSettingsIcon(systemName: feature.symbol, color: feature.color),
                title: feature.title,
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case let .featureBody(_, text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
            )
        case let .footer(text):
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(text),
                sectionId: self.section
            )
        }
    }
}

private func fenixAboutEntries(presentationData: PresentationData) -> [FenixAboutEntry] {
    let l10n = FenixuzL10n(presentationData.strings)
    let langCode = presentationData.strings.primaryComponent.languageCode
    var entries: [FenixAboutEntry] = []

    // Intro
    entries.append(.introHeader(l10n.about_introHeader))
    entries.append(.introBody(l10n.about_introBody))

    // Every Novagram feature — icon/title row + a three-part (Enable/How it works/Disable) body.
    for (index, feature) in aboutFeatures(langCode: langCode).enumerated() {
        entries.append(.featureRow(index, feature, presentationData.theme))
        entries.append(.featureBody(index, feature.body))
    }

    // Closing attribution
    entries.append(.footer(l10n.about_footer))

    return entries.sorted()
}

public func fenixAboutController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let l10n = FenixuzL10n(presentationData.strings)
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(l10n.about_screenTitle),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: fenixAboutEntries(presentationData: presentationData),
            style: .blocks
        )
        return (controllerState, (listState, ()))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
