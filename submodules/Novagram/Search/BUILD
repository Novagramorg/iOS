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
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Novagram/ChatLock:NovagramChatLock",
        "//submodules/Novagram/SecretVault:NovagramSecretVault",
    ],
    visibility = [
        "//visibility:public",
    ],
)
