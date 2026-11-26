load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# App Store rating prompt glue: the one ReviewPromptCenter of the app, success counting, the chat-list trigger and
# the Settings "Rate Novagram" row. The rules and the stored state are the SDK's (ReviewPromptKit, see HOOKS.md).
novagram_module(
    name = "NovagramReviewPrompt",
    module_name = "NovagramReviewPrompt",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Novagram/ReviewPromptKit:NovagramReviewPromptCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
