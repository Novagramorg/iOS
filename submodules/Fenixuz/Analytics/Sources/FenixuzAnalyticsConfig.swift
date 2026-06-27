import Foundation

// Fenixuz Analytics — Firebase Realtime Database (REST) configuration.
//
// The iOS app is Bazel-built (no CocoaPods/SPM), so we deliberately DO NOT pull in the
// Firebase SDK. Instead we read/write the same Realtime Database the Android app uses via
// its plain REST API (a couple of HTTPS calls). That keeps the numbers identical across
// both apps.
//
// TODO(Firebase): fill these in from the Android developer's Firebase project. Until
// `databaseURL` is non-empty, every analytics call is a no-op (no network, nothing
// counted) and the Analytics screen shows "—". Confirm the paths match the Android side
// exactly, otherwise the counters won't line up.
public enum FenixuzAnalyticsConfig {
    // Realtime Database URL, NO trailing slash.
    // e.g. "https://novagram-xxxx-default-rtdb.firebaseio.com"
    public static let databaseURL: String = ""

    // Optional RTDB auth token / database secret, appended as ?auth=… on every request.
    // Leave empty if the database rules allow unauthenticated writes.
    public static let authToken: String = ""

    // Single-integer node holding the distinct-device count ("Number of Novagram users").
    public static let deviceCountPath: String = "stats/deviceCount"

    // Single-integer node holding the cumulative account-registration count
    // ("Active accounts"). Only ever incremented — never decremented on logout.
    public static let accountCountPath: String = "stats/accountCount"

    // Parent path for per-device presence records: devices/<deviceId> = true.
    public static let devicesPath: String = "devices"

    public static var isConfigured: Bool {
        return !databaseURL.isEmpty
    }
}
