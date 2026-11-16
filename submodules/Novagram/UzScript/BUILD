load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# "Yangi alifbo": the send step and the on-screen conversion of chat messages to the new Uzbek Latin alphabet.
# Kept small on purpose: the chat bubble (ChatMessageTextBubbleContentNode) depends on it. No Postbox here.
swift_library(
    name = "NovagramUzScript",
    module_name = "NovagramUzScript",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Novagram/UzScriptKit:NovagramUzScriptCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
