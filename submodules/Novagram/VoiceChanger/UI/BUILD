load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Voice changer UI (HOOKS.md, "Voice changer"): the effects page, the button above the lock while a voice message is
# recorded, and the entries on the call screens. No chat or call module here, so the chat input panel and the call
# screens can depend on it.
swift_library(
    name = "NovagramVoiceChangerUI",
    module_name = "NovagramVoiceChangerUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/Novagram/VoiceChanger:NovagramVoiceChanger",
    ],
    visibility = ["//visibility:public"],
)
