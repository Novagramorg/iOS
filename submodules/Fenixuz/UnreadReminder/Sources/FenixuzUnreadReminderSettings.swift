import Foundation

/// Shared accessor for the "Unread message reminder" (Xabar eslatmasi) settings.
/// Lives in the same `pro_messager` UserDefaults suite as every other Fenix setting,
/// so the settings UI and the manager always read identical keys without duplicating
/// string literals across modules.
public enum FenixuzUnreadReminderSettings {
    static let suiteName = "pro_messager"

    static let enabledKey = "unread_reminder_enabled"
    static let minutesKey = "unread_reminder_minutes"
    static let soundKey = "unread_reminder_sound"

    // Default reminder threshold when the user has not picked one.
    public static let defaultMinutes = 5
    // Default sound key — maps to the system default notification sound.
    public static let defaultSound = "default"

    // Selectable minute thresholds shown in the picker.
    public static let minuteOptions: [Int] = [1, 5, 10, 30, 60]

    // Selectable reminder tones shown in the sound picker. "default" and "none"
    // are handled specially; every other key maps to a bundled .caf via fileName(for:).
    public static let soundOptions: [String] = ["default", "chime", "glass", "bell", "note", "tritone", "marimba", "crystal", "droplet", "ping", "pulse", "harp", "signal", "none"]

    /// Bundled .caf filename for a sound key, or nil for the special "default"/"none" keys
    /// (which do not correspond to a bundled file). Used both for notification playback
    /// (UNNotificationSound(named:)) and for in-app preview.
    public static func fileName(for key: String) -> String? {
        switch key {
        case "default", "none":
            return nil
        default:
            return soundOptions.contains(key) ? "\(key).caf" : nil
        }
    }

    /// The bundle that actually contains the .caf tones. Bazel packs a swift_library's
    /// `data` files into the FRAMEWORK the module compiles into (TelegramUIFramework),
    /// NOT the app's main bundle — so `Bundle.main` can never find them.
    public static var soundsBundle: Bundle {
        return Bundle(for: BundleToken.self)
    }

    /// Copies the bundled tones into <App>/Library/Sounds so `UNNotificationSound(named:)`
    /// can resolve them: the notification system only looks in the main bundle root or
    /// Library/Sounds, never inside a framework. Idempotent; cheap after the first run.
    public static func installBundledSoundsIfNeeded() {
        let fm = FileManager.default
        guard let library = try? fm.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return
        }
        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        let bundle = soundsBundle
        for key in soundOptions {
            guard let fileName = fileName(for: key) else {
                continue
            }
            let dest = soundsDir.appendingPathComponent(fileName)
            if fm.fileExists(atPath: dest.path) {
                continue
            }
            let base = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            guard let src = bundle.url(forResource: base, withExtension: ext) else {
                continue
            }
            try? fm.copyItem(at: src, to: dest)
        }
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    public static var isEnabled: Bool {
        defaults?.object(forKey: enabledKey) as? Bool ?? false
    }

    public static var minutes: Int {
        defaults?.object(forKey: minutesKey) as? Int ?? defaultMinutes
    }

    public static var sound: String {
        defaults?.string(forKey: soundKey) ?? defaultSound
    }
}

// Marker used only to locate this module's framework bundle (where Bazel packs the
// .caf tones) via Bundle(for:).
private final class BundleToken {}
