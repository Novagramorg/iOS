import Foundation

// The installed version and build, shown at the bottom of the Settings tab
// ("Novagram 13.0 (85)") so users and support can tell which build is running.
public enum NovagramAppVersion {
    public static var displayText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Novagram \(version) (\(build))"
    }
}
