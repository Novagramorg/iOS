load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramCarPlay",
    module_name = "NovagramCarPlay",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/Novagram/SecretVault:NovagramSecretVault",
        "//submodules/Novagram/ChatLock:NovagramChatLock",
    ],
    visibility = [
        "//visibility:public",
    ],
)
