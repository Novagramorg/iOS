import Foundation

// Fenixuz Analytics — Novagram Statistics API (REST) configuration.
//
// Backend: https://statistics.novagram.org (FastAPI). This replaces the earlier Firebase
// Realtime Database approach — dedup now happens SERVER-SIDE by `device_id`, so the client
// just fires simple idempotent calls and never has to manage its own counters. The Android
// app talks to the same backend, so the numbers stay identical across both platforms.
//
// This file is intentionally dependency-free (Foundation only) so it can be copied as-is
// into the macOS (TelegramSwift) target later, alongside FenixuzStatisticsClient.swift.
public enum FenixuzAnalyticsConfig {
    // Base URL, NO trailing slash.
    public static let baseURL: String = "https://statistics.novagram.org"

    // x-api-key header value. The server enforces this on /install, /account/* and /stats —
    // a request without it gets HTTP 401. This is not a high-value secret (at most it lets
    // someone inflate public counters), so it lives here the same way the demo-login endpoint
    // does. Move to a build-time injected value if that ever changes.
    public static let apiKey: String = "fbebe2c70b4ac933afce001192f3cdf6f88624d65317ddc3c63bf067577e8c3a"

    // Endpoint paths (relative to baseURL).
    public static let installPath: String = "/v1/install"          // downloads +1 (per device)
    public static let accountCreatePath: String = "/v1/account/create"  // active +1
    public static let accountDeletePath: String = "/v1/account/delete"  // active -1
    public static let statsPath: String = "/v1/stats"              // { downloads, active }

    public static var isConfigured: Bool {
        return !baseURL.isEmpty && !apiKey.isEmpty
    }
}
