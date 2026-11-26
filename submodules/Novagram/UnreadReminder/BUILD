load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramUnreadReminder",
    module_name = "NovagramUnreadReminder",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
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
