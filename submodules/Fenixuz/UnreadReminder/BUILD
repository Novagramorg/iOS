load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzUnreadReminder",
    module_name = "FenixuzUnreadReminder",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    # Bundled reminder tones. Attaching them as `data` to the swift_library makes
    # rules_apple flatten each .caf to the app bundle root, which is where
    # UNNotificationSound(named:) resolves them from (Bundle.main).
    data = glob([
        "Sounds/*.caf",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
    ],
    visibility = [
        "//visibility:public",
    ],
)
