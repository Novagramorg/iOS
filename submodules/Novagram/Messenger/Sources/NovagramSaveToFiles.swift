import Foundation
import TelegramCore

/// "Save to Files" for voice messages and files (HOOKS.md, "Save to Files"). Telegram offers it only for music.
/// While the Developer switch is on, the message menu also offers it for voice messages, audio and documents in any
/// chat, group or channel. Copy-protected chats keep Telegram's rule: no Save to Files.
public enum NovagramSaveToFiles {
    /// Can this file be saved with "Save to Files"? Telegram's own rule (music) or, with the switch on, a voice
    /// message or a document. Photos and videos already have "Save to Gallery"; stickers, GIFs, emoji and round
    /// videos are left out.
    public static func canSave(_ file: TelegramMediaFile) -> Bool {
        if file.isMusic {
            return true
        }
        guard NovagramDeveloperFlags.isSaveToFilesEnabled else {
            return false
        }
        if file.isVoice {
            return true
        }
        if file.isSticker || file.isAnimated || file.isAnimatedSticker || file.isVideoSticker || file.isCustomEmoji || file.isInstantVideo || file.isVideo {
            return false
        }
        return true
    }

    /// The extension of the saved file when its name has none. Voice messages are Ogg Opus.
    public static func defaultExtension(_ file: TelegramMediaFile) -> String? {
        if file.isVoice {
            return "ogg"
        }
        switch file.mimeType.lowercased() {
        case "audio/ogg", "audio/opus":
            return "ogg"
        case "audio/mp4", "audio/m4a", "audio/x-m4a":
            return "m4a"
        case "audio/wav", "audio/x-wav":
            return "wav"
        case "application/pdf":
            return "pdf"
        case "application/zip":
            return "zip"
        default:
            return nil
        }
    }

    /// The name (no extension) for a file that has no name and no title: "Voice message 2026-11-10 14.05".
    public static func fallbackBaseName(_ file: TelegramMediaFile, date: Date = Date()) -> String? {
        guard file.isVoice || file.fileName == nil else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let prefix = file.isVoice ? "Voice message" : "File"
        return "\(prefix) \(formatter.string(from: date))"
    }
}
