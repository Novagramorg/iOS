// Local string namespace for the Features section (#19, #21, #32, #40, #45).
// Kept in ProMessager to avoid parallel-edit hazard on the shared Localization module.

enum FenixFeaturesStrings {
    static func sectionTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Imkoniyatlar"
        case "ru": return "Функции"
        case "zh": return "功能"
        default:   return "Features"
        }
    }

    static func addFoldersTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Tavsiya etilgan papkalar"
        case "ru": return "Рекомендуемые папки"
        case "zh": return "推荐分组"
        default:   return "Recommended folders"
        }
    }

    static func addFoldersTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Shaxsiy, O'qilmagan, Kanallar va Botlar papkalarini bir marta bosib qo'shadi"
        case "ru": return "Добавляет папки Личные, Непрочитанные, Каналы и Боты одним нажатием"
        case "zh": return "一键添加“个人”“未读”“频道”和“机器人”分组"
        default:   return "Adds Personal, Unread, Channels and Bots folders in one tap"
        }
    }

    static func folderStyleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papka ko'rinishi"
        case "ru": return "Стиль папок"
        case "zh": return "分组显示样式"
        default:   return "Folder display style"
        }
    }

    static func folderStyleLabel(_ style: String, langCode: String) -> String {
        switch style {
        case "icon":
            switch langCode {
            case "uz": return "Ikonkalar"
            case "ru": return "Иконки"
            case "zh": return "图标"
            default:   return "Icons"
            }
        case "text":
            switch langCode {
            case "uz": return "Matn"
            case "ru": return "Текст"
            case "zh": return "文字"
            default:   return "Text"
            }
        default:
            // "auto" and any unknown value
            switch langCode {
            case "uz": return "Avtomatik"
            case "ru": return "Авто"
            case "zh": return "自动"
            default:   return "Automatic"
            }
        }
    }

    static func channelHistoryTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Kanal tarixi tugmasi"
        case "ru": return "Кнопка истории канала"
        case "zh": return "频道历史按钮"
        default:   return "Channel history button"
        }
    }

    static func channelHistoryTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Kanal menyusiga \"So'nggi amallar\" bandini qo'shadi (siz admin bo'lgan kanallarda)"
        case "ru": return "Добавляет пункт «Недавние действия» в меню канала (где вы администратор)"
        case "zh": return "在频道菜单中添加“最近操作”选项（仅限你是管理员的频道）"
        default:   return "Adds a \"Recent actions\" item to the channel menu (where you're an admin)"
        }
    }

    static func settingsLinksTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Sozlamalar havolalari"
        case "ru": return "Ссылки в настройках"
        case "zh": return "设置链接"
        default:   return "Settings links"
        }
    }

    static func settingsLinksTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram Settings sahifasiga havolani nusxalash va ulashish imkonini beradi"
        case "ru": return "Позволяет копировать и делиться ссылкой на страницу Novagram Settings"
        case "zh": return "可复制并分享 Novagram 设置页面的链接"
        default:   return "Lets you copy and share a link to the Novagram Settings page"
        }
    }

    static func autoAcceptTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avto-qabul qilish"
        case "ru": return "Авто-принятие запросов"
        case "zh": return "自动通过入群申请"
        default:   return "Auto-accept requests"
        }
    }

    static func autoAcceptTip(langCode: String) -> String {
        switch langCode {
        case "uz": return "Guruh/kanal qo'shilish so'rovlarini avtomatik qabul qiladi"
        case "ru": return "Автоматически принимает запросы на вступление в группы/каналы"
        case "zh": return "自动通过群组和频道的加入申请"
        default:   return "Automatically accepts join requests for groups and channels"
        }
    }

    // Feature #40: share NovagramPro settings link
    static func shareNovagramProLinkTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram Settings havolasini ulashish"
        case "ru": return "Поделиться ссылкой Novagram Settings"
        case "zh": return "分享 Novagram 设置链接"
        default:   return "Share Novagram Settings link"
        }
    }

    static func shareNovagramProLinkCopied(langCode: String) -> String {
        switch langCode {
        case "uz": return "Havola nusxalandi"
        case "ru": return "Ссылка скопирована"
        case "zh": return "链接已复制"
        default:   return "Link copied"
        }
    }

    static func footer(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Novagramning kengaytirilgan imkoniyatlari. Har birini shu yerdan yoqib-o'chirishingiz mumkin."
        case "ru":
            return "Расширенные функции Novagram. Каждую можно включить или выключить здесь."
        case "zh":
            return "Novagram 的扩展功能，每一项都可以在这里单独开启或关闭。"
        default:
            return "Novagram's extended features. Turn each one on or off right here."
        }
    }

    // First-launch alert strings
    static func addFoldersAlertTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papkalar qo'shilsinmi?"
        case "ru": return "Добавить папки?"
        case "zh": return "添加分组？"
        default:   return "Add folders?"
        }
    }

    static func addFoldersAlertText(langCode: String) -> String {
        switch langCode {
        case "uz":
            return "Shaxsiy, O'qilmagan, Kanallar va Botlar nomli 4 ta papka avtomatik qo'shiladi."
        case "ru":
            return "Будут автоматически добавлены 4 папки: Личные, Непрочитанные, Каналы и Боты."
        case "zh":
            return "将自动添加 4 个分组：“个人”“未读”“频道”和“机器人”。"
        default:
            return "4 folders will be added automatically: Personal, Unread, Channels and Bots."
        }
    }

    static func addFoldersAlertConfirm(langCode: String) -> String {
        switch langCode {
        case "uz": return "Qo'shish"
        case "ru": return "Добавить"
        case "zh": return "添加"
        default:   return "Add"
        }
    }

    static func addedToastMessage(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papkalar qo'shildi"
        case "ru": return "Папки добавлены"
        case "zh": return "分组已添加"
        default:   return "Folders added"
        }
    }

    // Folder names (localized per language)
    static func folderNamePersonal(langCode: String) -> String {
        switch langCode {
        case "uz": return "Shaxsiy"
        case "ru": return "Личные"
        case "zh": return "个人"
        default:   return "Personal"
        }
    }

    static func folderNameUnread(langCode: String) -> String {
        switch langCode {
        case "uz": return "O'qilmagan"
        case "ru": return "Непрочитанные"
        case "zh": return "未读"
        default:   return "Unread"
        }
    }

    static func folderNameChannels(langCode: String) -> String {
        switch langCode {
        case "uz": return "Kanallar"
        case "ru": return "Каналы"
        case "zh": return "频道"
        default:   return "Channels"
        }
    }

    static func folderNameBots(langCode: String) -> String {
        switch langCode {
        case "uz": return "Botlar"
        case "ru": return "Боты"
        case "zh": return "机器人"
        default:   return "Bots"
        }
    }
}
