// Local string namespace for the Features section (#19, #21, #32, #40, #45).
// Kept in ProMessager to avoid parallel-edit hazard on the shared Localization module.

enum FenixFeaturesStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Imkoniyatlar"
        case "ru": return "Функции"
        default:   return "Features"
        }
    }

    static func addFoldersTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Tavsiya etilgan papkalar"
        case "ru": return "Рекомендуемые папки"
        default:   return "Recommended folders"
        }
    }

    static func addFoldersTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Shaxsiy, O'qilmagan, Kanallar va Botlar papkalarini bir marta bosib qo'shadi"
        case "ru": return "Добавляет папки Личные, Непрочитанные, Каналы и Боты одним нажатием"
        default:   return "Adds Personal, Unread, Channels and Bots folders in one tap"
        }
    }

    static func folderStyleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papka ko'rinishi"
        case "ru": return "Стиль папок"
        default:   return "Folder display style"
        }
    }

    static func folderStyleLabel(_ style: String, langCode: String) -> String {
        switch style {
        case "icon":
            switch langCode {
            case "uz": return "Ikonkalar"
            case "ru": return "Иконки"
            default:   return "Icons"
            }
        case "text":
            switch langCode {
            case "uz": return "Matn"
            case "ru": return "Текст"
            default:   return "Text"
            }
        default:
            // "auto" and any unknown value
            switch langCode {
            case "uz": return "Avtomatik"
            case "ru": return "Авто"
            default:   return "Automatic"
            }
        }
    }

    static func channelHistoryTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Kanal tarixi tugmasi"
        case "ru": return "Кнопка истории канала"
        default:   return "Channel history button"
        }
    }

    static func channelHistoryTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Kanal menyusiga \"So'nggi amallar\" bandini qo'shadi (siz admin bo'lgan kanallarda)"
        case "ru": return "Добавляет пункт «Недавние действия» в меню канала (где вы администратор)"
        default:   return "Adds a \"Recent actions\" item to the channel menu (where you're an admin)"
        }
    }

    static func settingsLinksTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Sozlamalar havolalari"
        case "ru": return "Ссылки в настройках"
        default:   return "Settings links"
        }
    }

    static func settingsLinksTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "NovagramPro sahifasiga havolani nusxalash va ulashish imkonini beradi"
        case "ru": return "Позволяет копировать и делиться ссылкой на страницу NovagramPro"
        default:   return "Lets you copy and share a link to the NovagramPro page"
        }
    }

    static func autoAcceptTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avto-qabul qilish"
        case "ru": return "Авто-принятие запросов"
        default:   return "Auto-accept requests"
        }
    }

    static func autoAcceptTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Guruh/kanal qo'shilish so'rovlarini avtomatik qabul qiladi"
        case "ru": return "Автоматически принимает запросы на вступление в группы/каналы"
        default:   return "Automatically accepts join requests for groups and channels"
        }
    }

    // Feature #40: share NovagramPro settings link
    static func shareNovagramProLinkTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "NovagramPro havolasini ulashish"
        case "ru": return "Поделиться ссылкой NovagramPro"
        default:   return "Share NovagramPro link"
        }
    }

    static func shareNovagramProLinkCopied(langCode: String) -> String {
        switch langCode {
        case "uz": return "Havola nusxalandi"
        case "ru": return "Ссылка скопирована"
        default:   return "Link copied"
        }
    }

    static func footer(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Novagramning kengaytirilgan imkoniyatlari. Har birini shu yerdan yoqib-o'chirishingiz mumkin."
        case "ru":
            return "Расширенные функции Novagram. Каждую можно включить или выключить здесь."
        default:
            return "Novagram's extended features. Turn each one on or off right here."
        }
    }

    // First-launch alert strings
    static func addFoldersAlertTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papkalar qo'shilsinmi?"
        case "ru": return "Добавить папки?"
        default:   return "Add folders?"
        }
    }

    static func addFoldersAlertText(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Shaxsiy, O'qilmagan, Kanallar va Botlar nomli 4 ta papka avtomatik qo'shiladi."
        case "ru":
            return "Будут автоматически добавлены 4 папки: Личные, Непрочитанные, Каналы и Боты."
        default:
            return "4 folders will be added automatically: Personal, Unread, Channels and Bots."
        }
    }

    static func addFoldersAlertConfirm(langCode: String) -> String {
        switch langCode {
        case "uz": return "Qo'shish"
        case "ru": return "Добавить"
        default:   return "Add"
        }
    }

    static func addedToastMessage(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papkalar qo'shildi"
        case "ru": return "Папки добавлены"
        default:   return "Folders added"
        }
    }

    // Folder names (localized per language)
    static func folderNamePersonal(langCode: String) -> String {
        switch langCode {
        case "uz": return "Shaxsiy"
        case "ru": return "Личные"
        default:   return "Personal"
        }
    }

    static func folderNameUnread(langCode: String) -> String {
        switch langCode {
        case "uz": return "O'qilmagan"
        case "ru": return "Непрочитанные"
        default:   return "Unread"
        }
    }

    static func folderNameChannels(langCode: String) -> String {
        switch langCode {
        case "uz": return "Kanallar"
        case "ru": return "Каналы"
        default:   return "Channels"
        }
    }

    static func folderNameBots(langCode: String) -> String {
        switch langCode {
        case "uz": return "Botlar"
        case "ru": return "Боты"
        default:   return "Bots"
        }
    }
}
