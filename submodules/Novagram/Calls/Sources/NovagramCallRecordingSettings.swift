import Foundation

/// The call recording switches in Novagram Settings → Calls (HOOKS.md, "Call recording").
/// Same keys as the Mac, in the `pro_messager` suite, all default off. The Mac's `novagram_call_recording_folder`
/// is a security-scoped bookmark there and is not used on iOS: recordings always go to the app's own folder.
public enum NovagramCallRecordingSettings {
    public static let enabledKey = "novagram_call_recording"
    public static let autoKey = "novagram_call_recording_auto"
    // Set once the first-recording consent alert was accepted.
    public static let warnedKey = "novagram_call_recording_warned"

    private static var defaults: UserDefaults? {
        return UserDefaults(suiteName: "pro_messager")
    }

    /// The "Call recording" switch: adds the Record control to 1:1 calls.
    public static var isEnabled: Bool {
        get {
            return self.defaults?.bool(forKey: self.enabledKey) ?? false
        }
        set {
            self.defaults?.set(newValue, forKey: self.enabledKey)
        }
    }

    /// "Record every call automatically". Only takes effect while `isEnabled` is on.
    public static var isAutoEnabled: Bool {
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
