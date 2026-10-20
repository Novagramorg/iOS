load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzCarPlay",
    module_name = "FenixuzCarPlay",
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
        "//submodules/Fenixuz/Localization:FenixuzLocalization",
        "//submodules/Fenixuz/SecretVault:FenixuzSecretVault",
        "//submodules/Fenixuz/ChatLock:FenixuzChatLock",
    ],
    visibility = [
        "//visibility:public",
    ],
)
