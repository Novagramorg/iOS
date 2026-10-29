load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramSearch",
    module_name = "NovagramSearch",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Display:Display",
        "//submodules/AppBundle:AppBundle",
        "//submodules/ContextUI:ContextUI",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUI/Components/ChatScheduleTimeController:ChatScheduleTimeController",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/Novagram/ChatLock:NovagramChatLock",
        "//submodules/Novagram/SecretVault:NovagramSecretVault",
    ],
    visibility = [
        "//visibility:public",
    ],
)
