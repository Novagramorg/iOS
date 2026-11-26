load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramSearch",
    module_name = "NovagramSearch",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Novagram/ChatLock:NovagramChatLock",
        "//submodules/Novagram/SecretVault:NovagramSecretVault",
    ],
    visibility = [
        "//visibility:public",
    ],
)
