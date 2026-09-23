import Foundation

// MARK: - Codable models for novagram_bots.json

struct NovagramBotLocalizedText: Codable {
    let en: String
    let uz: String
    let ru: String
    // Optional so a JSON copy without Chinese still decodes.
    let zh: String?

    func localized(langCode: String) -> String {
        switch langCode {
        case "uz": return uz
        case "ru": return ru
        case "zh": return zh ?? en
        default:   return en
        }
    }
}

struct NovagramBot: Codable {
    let id: String
    let username: String
    let name: String
    let icon: String
    let emoji: String
    let color: String
    let help: NovagramBotLocalizedText
}

struct NovagramBotCategory: Codable {
    let id: String
    let title: NovagramBotLocalizedText
    let bots: [NovagramBot]
}

struct NovagramBotsRoot: Codable {
    let categories: [NovagramBotCategory]
}

// MARK: - Localized row title (used by FenixSettingsController)

enum FenixBotsStrings {
    static func rowTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram Botlar"
        case "ru": return "Боты Novagram"
        case "zh": return "Novagram 机器人"
        default:   return "Novagram Bots"
        }
    }

    static func screenTitle(langCode: String) -> String {
        return rowTitle(langCode: langCode)
    }
}

// MARK: - Localized Settings-section row titles
// Titles for the three Fenixuz rows at the top of the main Settings screen.
// Takes the app language (FenixuzL10n.languageKey(for: presentationData.strings)) as langCode — never Locale.current.

public enum FenixSettingsSectionStrings {
    public static func settingsRowTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Novagram sozlamalari"
        case "ru": return "Настройки Novagram"
        case "zh": return "Novagram 设置"
        default:   return "Novagram Settings"
        }
    }

    public static func botsRowTitle(langCode: String) -> String {
        return FenixBotsStrings.rowTitle(langCode: langCode)
    }

    public static func analyticsRowTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Analitika"
        case "ru": return "Аналитика"
        case "zh": return "统计"
        default:   return "Analytics"
        }
    }
}

// MARK: - Embedded JSON
// Verbatim copy of /Users/codingtech/Documents/Telegram/novagram_bots.json.
// The canonical source of truth is that file; this copy is bundled for runtime decoding.

private let novagramBotsJSONString = """
{
  "schemaVersion": 1,
  "updated": "2026-07-02",
  "note": "Canonical source of truth for the Novagram Bots page (iOS + macOS + web). Each platform bundles a copy in its own resources. 'icon' = SF Symbol name (iOS/macOS). 'emoji' = fallback for web / emoji contexts. Tapping a bot opens its @username via the platform's resolve-username flow.",
  "categories": [
    {
      "id": "downloaders",
      "title": { "en": "Downloaders", "uz": "Yuklovchilar", "ru": "Загрузчики", "zh": "下载工具" },
      "bots": [
        {
          "id": "youtube",
          "username": "novogram_youtube_bot",
          "name": "YouTube",
          "icon": "play.rectangle.fill",
          "emoji": "▶️",
          "color": "#FF0000",
          "help": {
            "en": "Download videos and music from YouTube",
            "uz": "YouTube'dan video va musiqa yuklab oling",
            "ru": "Скачивайте видео и музыку с YouTube",
            "zh": "从 YouTube 下载视频和音乐"
          }
        },
        {
          "id": "shazam",
          "username": "novagram_shazam_bot",
          "name": "Shazam",
          "icon": "music.mic",
          "emoji": "🎵",
          "color": "#08A0E9",
          "help": {
            "en": "Recognize any song playing around you",
            "uz": "Atrofda yangrayotgan istalgan qo'shiqni aniqlang",
            "ru": "Распознавайте любую играющую песню",
            "zh": "识别你身边正在播放的任何歌曲"
          }
        },
        {
          "id": "spotify",
          "username": "novagram_spotify_bot",
          "name": "Spotify",
          "icon": "music.note.list",
          "emoji": "🎧",
          "color": "#1DB954",
          "help": {
            "en": "Download tracks and playlists from Spotify",
            "uz": "Spotify'dan trek va playlistlarni yuklang",
            "ru": "Скачивайте треки и плейлисты из Spotify",
            "zh": "从 Spotify 下载单曲和歌单"
          }
        },
        {
          "id": "vk",
          "username": "novagram_vk_bot",
          "name": "VK",
          "icon": "play.square.stack.fill",
          "emoji": "🎬",
          "color": "#0077FF",
          "help": {
            "en": "Download videos and music from VK",
            "uz": "VK'dan video va musiqa yuklang",
            "ru": "Скачивайте видео и музыку из VK",
            "zh": "从 VK 下载视频和音乐"
          }
        },
        {
          "id": "rutube",
          "username": "novagram_rutube_bot",
          "name": "RuTube",
          "icon": "play.tv.fill",
          "emoji": "📺",
          "color": "#E5162D",
          "help": {
            "en": "Download videos from RuTube",
            "uz": "RuTube'dan videolarni yuklang",
            "ru": "Скачивайте видео с RuTube",
            "zh": "从 RuTube 下载视频"
          }
        },
        {
          "id": "twitch",
          "username": "novagram_twitch_bot",
          "name": "Twitch",
          "icon": "gamecontroller.fill",
          "emoji": "🎮",
          "color": "#9146FF",
          "help": {
            "en": "Download clips and streams from Twitch",
            "uz": "Twitch'dan klip va streamlarni yuklang",
            "ru": "Скачивайте клипы и стримы с Twitch",
            "zh": "从 Twitch 下载剪辑和直播"
          }
        },
        {
          "id": "pinterest",
          "username": "novagram_pinterest_bot",
          "name": "Pinterest",
          "icon": "pin.fill",
          "emoji": "📌",
          "color": "#E60023",
          "help": {
            "en": "Download images and videos from Pinterest",
            "uz": "Pinterest'dan rasm va videolarni yuklang",
            "ru": "Скачивайте изображения и видео из Pinterest",
            "zh": "从 Pinterest 下载图片和视频"
          }
        },
        {
          "id": "reddit",
          "username": "novagram_reddit_bot",
          "name": "Reddit",
          "icon": "bubble.left.and.bubble.right.fill",
          "emoji": "👽",
          "color": "#FF4500",
          "help": {
            "en": "Download videos and media from Reddit",
            "uz": "Reddit'dan video va mediani yuklang",
            "ru": "Скачивайте видео и медиа с Reddit",
            "zh": "从 Reddit 下载视频和媒体"
          }
        },
        {
          "id": "facebook",
          "username": "novagram_facebook_bot",
          "name": "Facebook",
          "icon": "video.square.fill",
          "emoji": "📘",
          "color": "#1877F2",
          "help": {
            "en": "Download videos from Facebook",
            "uz": "Facebook'dan videolarni yuklang",
            "ru": "Скачивайте видео из Facebook",
            "zh": "从 Facebook 下载视频"
          }
        },
        {
          "id": "twitter",
          "username": "novagram_twitter_bot",
          "name": "Twitter / X",
          "icon": "bird.fill",
          "emoji": "🐦",
          "color": "#1DA1F2",
          "help": {
            "en": "Download videos and GIFs from Twitter / X",
            "uz": "Twitter / X'dan video va GIF yuklang",
            "ru": "Скачивайте видео и GIF из Twitter / X",
            "zh": "从 Twitter / X 下载视频和 GIF"
          }
        },
        {
          "id": "tiktok",
          "username": "novagram_tiktok_bot",
          "name": "TikTok",
          "icon": "music.note",
          "emoji": "🎶",
          "color": "#111111",
          "help": {
            "en": "Download TikTok videos without watermark",
            "uz": "TikTok videolarini watermark'siz yuklang",
            "ru": "Скачивайте видео TikTok без водяного знака",
            "zh": "下载无水印的 TikTok 视频"
          }
        },
        {
          "id": "instagram",
          "username": "novagram_instagram_bot",
          "name": "Instagram",
          "icon": "camera.fill",
          "emoji": "📷",
          "color": "#E4405F",
          "help": {
            "en": "Download photos, Reels and Stories from Instagram",
            "uz": "Instagram'dan rasm, Reels va Storylarni yuklang",
            "ru": "Скачивайте фото, Reels и Stories из Instagram",
            "zh": "从 Instagram 下载照片、Reels 和快拍"
          }
        }
      ]
    },
    {
      "id": "media_tools",
      "title": { "en": "Media Tools", "uz": "Media vositalari", "ru": "Медиаинструменты", "zh": "媒体工具" },
      "bots": [
        {
          "id": "compress",
          "username": "novagram_compress_bot",
          "name": "Compress",
          "icon": "arrow.down.forward.and.arrow.up.backward",
          "emoji": "🗜️",
          "color": "#34C759",
          "help": {
            "en": "Compress photos and videos to save space",
            "uz": "Rasm va videolarni siqib joyni tejang",
            "ru": "Сжимайте фото и видео для экономии места",
            "zh": "压缩照片和视频，节省存储空间"
          }
        },
        {
          "id": "crop",
          "username": "novagram_crop_bot",
          "name": "Crop",
          "icon": "crop",
          "emoji": "✂️",
          "color": "#FF9500",
          "help": {
            "en": "Crop and resize photos and videos",
            "uz": "Rasm va videolarni kesing va o'lchamini o'zgartiring",
            "ru": "Обрезайте и меняйте размер фото и видео",
            "zh": "裁剪照片和视频并调整尺寸"
          }
        },
        {
          "id": "trimmer",
          "username": "novagram_trimmer_bot",
          "name": "Trimmer",
          "icon": "scissors",
          "emoji": "🎞️",
          "color": "#FF375F",
          "help": {
            "en": "Trim and cut video length",
            "uz": "Video uzunligini qirqing va kesing",
            "ru": "Обрезайте длину видео",
            "zh": "修剪视频，截取所需时长"
          }
        },
        {
          "id": "blur",
          "username": "novagram_blur_bot",
          "name": "Blur",
          "icon": "camera.filters",
          "emoji": "🌫️",
          "color": "#5856D6",
          "help": {
            "en": "Blur parts of a photo or video",
            "uz": "Rasm yoki videoning bir qismini xiralashtiring",
            "ru": "Размывайте части фото или видео",
            "zh": "模糊照片或视频的局部"
          }
        },
        {
          "id": "remover",
          "username": "novagram_remover_bot",
          "name": "BG Remover",
          "icon": "person.and.background.dotted",
          "emoji": "🧹",
          "color": "#AF52DE",
          "help": {
            "en": "Remove the background from any image",
            "uz": "Istalgan rasmning fonini olib tashlang",
            "ru": "Удаляйте фон с любого изображения",
            "zh": "去除任意图片的背景"
          }
        },
        {
          "id": "upscaler",
          "username": "novagram_upscaler_bot",
          "name": "Upscaler",
          "icon": "sparkles",
          "emoji": "✨",
          "color": "#00C7BE",
          "help": {
            "en": "Enhance and upscale image quality with AI",
            "uz": "AI bilan rasm sifatini yaxshilang va kattalashtiring",
            "ru": "Улучшайте и увеличивайте качество изображений с ИИ",
            "zh": "用 AI 提升图片画质和分辨率"
          }
        },
        {
          "id": "sticker",
          "username": "novagram_sticker_bot",
          "name": "Sticker Maker",
          "icon": "square.on.circle.fill",
          "emoji": "🎨",
          "color": "#FF2D55",
          "help": {
            "en": "Turn photos into Telegram stickers",
            "uz": "Rasmlarni Telegram stikerlariga aylantiring",
            "ru": "Превращайте фото в стикеры Telegram",
            "zh": "把照片变成 Telegram 贴纸"
          }
        },
        {
          "id": "voice",
          "username": "novagram_voice_bot",
          "name": "Voice",
          "icon": "waveform",
          "emoji": "🎙️",
          "color": "#FF9500",
          "help": {
            "en": "Extract and convert audio from media",
            "uz": "Mediadan audioni ajratib oling va aylantiring",
            "ru": "Извлекайте и конвертируйте аудио из медиа",
            "zh": "从媒体中提取并转换音频"
          }
        }
      ]
    },
    {
      "id": "utilities",
      "title": { "en": "Utilities", "uz": "Foydali vositalar", "ru": "Утилиты", "zh": "实用工具" },
      "bots": [
        {
          "id": "qr",
          "username": "novagram_qr_bot",
          "name": "QR Code",
          "icon": "qrcode",
          "emoji": "🔳",
          "color": "#1C1C1E",
          "help": {
            "en": "Create and scan QR codes",
            "uz": "QR kodlarni yarating va skanerlang",
            "ru": "Создавайте и сканируйте QR-коды",
            "zh": "生成和扫描二维码"
          }
        },
        {
          "id": "password",
          "username": "novagram_password_bot",
          "name": "Password",
          "icon": "key.fill",
          "emoji": "🔑",
          "color": "#8E8E93",
          "help": {
            "en": "Generate strong, secure passwords",
            "uz": "Kuchli va xavfsiz parollar yarating",
            "ru": "Генерируйте надёжные пароли",
            "zh": "生成高强度的安全密码"
          }
        },
        {
          "id": "tempmail",
          "username": "novagram_tempmail_bot",
          "name": "Temp Mail",
          "icon": "envelope.fill",
          "emoji": "📧",
          "color": "#007AFF",
          "help": {
            "en": "Get a temporary disposable email address",
            "uz": "Vaqtinchalik bir martalik email oling",
            "ru": "Получите временную одноразовую почту",
            "zh": "获取一次性临时邮箱地址"
          }
        },
        {
          "id": "pdf",
          "username": "novagram_pdf_bot",
          "name": "PDF Tools",
          "icon": "doc.richtext.fill",
          "emoji": "📄",
          "color": "#FF3B30",
          "help": {
            "en": "Convert, merge and edit PDF files",
            "uz": "PDF fayllarni aylantiring, birlashtiring va tahrirlang",
            "ru": "Конвертируйте, объединяйте и редактируйте PDF",
            "zh": "转换、合并和编辑 PDF 文件"
          }
        },
        {
          "id": "tts",
          "username": "novagram_tts_bot",
          "name": "Text to Speech",
          "icon": "speaker.wave.2.fill",
          "emoji": "🔊",
          "color": "#5AC8FA",
          "help": {
            "en": "Convert text into natural voice",
            "uz": "Matnni tabiiy ovozga aylantiring",
            "ru": "Преобразуйте текст в естественную речь",
            "zh": "将文字转换为自然的语音"
          }
        }
      ]
    },
    {
      "id": "fun_info",
      "title": { "en": "Fun & Info", "uz": "Qiziqarli", "ru": "Разное", "zh": "趣味与资讯" },
      "bots": [
        {
          "id": "meme",
          "username": "novagram_meme_bot",
          "name": "Memes",
          "icon": "face.smiling",
          "emoji": "😂",
          "color": "#FFCC00",
          "help": {
            "en": "Fresh memes on demand",
            "uz": "Talab bo'yicha yangi memlar",
            "ru": "Свежие мемы по запросу",
            "zh": "随时获取新鲜梗图"
          }
        },
        {
          "id": "translit",
          "username": "novagram_translit_bot",
          "name": "Transliterator",
          "icon": "textformat.abc",
          "emoji": "🔤",
          "color": "#34C759",
          "help": {
            "en": "Convert text between Latin and Cyrillic",
            "uz": "Matnni lotin va kirill o'rtasida o'giring",
            "ru": "Конвертируйте текст между латиницей и кириллицей",
            "zh": "在拉丁字母和西里尔字母之间转换文字"
          }
        },
        {
          "id": "wallpaper",
          "username": "novagram_wallpaper_bot",
          "name": "Wallpapers",
          "icon": "photo.on.rectangle.angled",
          "emoji": "🖼️",
          "color": "#AF52DE",
          "help": {
            "en": "Browse and download HD wallpapers",
            "uz": "HD fon rasmlarini ko'ring va yuklang",
            "ru": "Просматривайте и скачивайте HD-обои",
            "zh": "浏览并下载高清壁纸"
          }
        },
        {
          "id": "movies",
          "username": "novagram_movies_bot",
          "name": "Movies",
          "icon": "film.fill",
          "emoji": "🎬",
          "color": "#FF375F",
          "help": {
            "en": "Search movies and series",
            "uz": "Kino va seriallarni qidiring",
            "ru": "Ищите фильмы и сериалы",
            "zh": "搜索电影和剧集"
          }
        },
        {
          "id": "weather",
          "username": "novagram_weather_bot",
          "name": "Weather",
          "icon": "cloud.sun.fill",
          "emoji": "⛅",
          "color": "#32ADE6",
          "help": {
            "en": "Check the weather forecast anywhere",
            "uz": "Istalgan joyda ob-havo ma'lumotini oling",
            "ru": "Узнавайте прогноз погоды где угодно",
            "zh": "查看任意地点的天气预报"
          }
        },
        {
          "id": "rates",
          "username": "novagram_rates_bot",
          "name": "Currency Rates",
          "icon": "dollarsign.circle.fill",
          "emoji": "💱",
          "color": "#30D158",
          "help": {
            "en": "Live currency exchange rates",
            "uz": "Jonli valyuta kurslari",
            "ru": "Актуальные курсы валют",
            "zh": "实时货币汇率"
          }
        },
        {
          "id": "facts",
          "username": "novagram_facts_bot",
          "name": "Facts",
          "icon": "lightbulb.fill",
          "emoji": "💡",
          "color": "#FFD60A",
          "help": {
            "en": "Discover interesting facts",
            "uz": "Qiziqarli faktlarni kashf eting",
            "ru": "Открывайте интересные факты",
            "zh": "发现有趣的冷知识"
          }
        },
        {
          "id": "quotes",
          "username": "novagram_quotes_bot",
          "name": "Quotes",
          "icon": "quote.bubble.fill",
          "emoji": "💬",
          "color": "#5856D6",
          "help": {
            "en": "Daily inspirational quotes",
            "uz": "Kunlik ilhomlantiruvchi iqtiboslar",
            "ru": "Ежедневные вдохновляющие цитаты",
            "zh": "每日励志名言"
          }
        },
        {
          "id": "proverbs",
          "username": "novagram_proverbs_bot",
          "name": "Proverbs",
          "icon": "book.fill",
          "emoji": "📖",
          "color": "#A2845E",
          "help": {
            "en": "Wise proverbs and sayings",
            "uz": "Dono maqol va matallar",
            "ru": "Мудрые пословицы и поговорки",
            "zh": "智慧谚语与格言"
          }
        }
      ]
    }
  ]
}
"""

// MARK: - Loader

func loadNovagramBots() -> NovagramBotsRoot? {
    guard let data = novagramBotsJSONString.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(NovagramBotsRoot.self, from: data)
}
