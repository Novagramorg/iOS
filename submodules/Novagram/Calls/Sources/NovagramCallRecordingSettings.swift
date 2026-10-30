import Foundation

/// The call recording switches in Novagram Settings → Calls (HOOKS.md, "Call recording").
/// Same keys as the Mac, in the `pro_messager` suite, all default off. The Mac's `novagram_call_recording_folder`
/// is a security-scoped bookmark there and is not used on iOS: recordings always go to the app's own folder.
///
/// The whole feature also sits behind the hidden Developer switch "Call recording (beta)"
/// (`novagram_dev_call_recording`, missing key = off). With it off `isEnabled` and `isAutoEnabled` are false and
/// the Settings rows are hidden; the user's own switches keep their values (`isUserEnabled`, `isUserAutoEnabled`).
public enum NovagramCallRecordingSettings {
    public static let enabledKey = "novagram_call_recording"
    public static let autoKey = "novagram_call_recording_auto"
    // Set once the first-recording consent alert was accepted.
    public static let warnedKey = "novagram_call_recording_warned"
    /// The Developer switch. Same key as the Mac. Written only by the Developer section (NovagramDeveloperFlags).
    public static let developerFlagKey = "novagram_dev_call_recording"

    /// Posted when a call changes a switch or saves a recording. Novagram Settings listens, because the call UI sits
    /// in its own window level and closing it does not make the Settings screen appear again.
    public static let changedNotification = Notification.Name("NovagramCallRecordingChanged")

    public static func notifyChanged() {
        NotificationCenter.default.post(name: self.changedNotification, object: nil)
    }

    private static var defaults: UserDefaults? {
        return UserDefaults(suiteName: "pro_messager")
    }

    /// The Developer switch "Call recording (beta)". Missing key = off.
    public static var isDeveloperEnabled: Bool {
        return self.defaults?.object(forKey: self.developerFlagKey) as? Bool ?? false
    }

    /// What calls read: the Developer switch and the user's "Call recording" switch are both on.
    /// Adds the Record control to 1:1 calls.
    public static var isEnabled: Bool {
        return self.isDeveloperEnabled && self.isUserEnabled
    }

    /// "Record every call automatically", gated by the Developer switch. Only takes effect while `isEnabled` is on.
    public static var isAutoEnabled: Bool {
        return self.isDeveloperEnabled && self.isUserAutoEnabled
    }

    /// The user's "Call recording" switch as stored. Only the Settings row reads and writes it.
    public static var isUserEnabled: Bool {
        get {
            return self.defaults?.bool(forKey: self.enabledKey) ?? false
        }
        set {
            self.defaults?.set(newValue, forKey: self.enabledKey)
        }
    }

    /// The user's "Record every call automatically" switch as stored.
    public static var isUserAutoEnabled: Bool {
        get {
            return self.defaults?.bool(forKey: self.autoKey) ?? false
        }
        set {
            self.defaults?.set(newValue, forKey: self.autoKey)
        }
    }

    public static var wasWarned: Bool {
        get {
            return self.defaults?.bool(forKey: self.warnedKey) ?? false
        }
        set {
            self.defaults?.set(newValue, forKey: self.warnedKey)
        }
    }
}
