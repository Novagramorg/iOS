load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# "Yangi alifbo": the send step and the on-screen conversion of chat messages to the new Uzbek Latin alphabet.
# Kept small on purpose: the chat bubble (ChatMessageTextBubbleContentNode) depends on it. No Postbox here.
novagram_module(
    name = "NovagramUzScript",
    module_name = "NovagramUzScript",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
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
