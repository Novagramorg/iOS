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
