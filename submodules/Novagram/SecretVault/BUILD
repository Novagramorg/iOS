load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramSecretVault",
    module_name = "NovagramSecretVault",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Novagram/ChatLock:NovagramChatLock",
    ],
    visibility = [
        "//visibility:public",
    ],
)
