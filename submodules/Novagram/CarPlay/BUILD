load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramCarPlay",
    module_name = "NovagramCarPlay",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
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
