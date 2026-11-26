load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Voice changer UI (HOOKS.md, "Voice changer"): the effects page, the button above the lock while a voice message is
# recorded, and the entries on the call screens. No chat or call module here, so the chat input panel and the call
# screens can depend on it.
novagram_module(
    name = "NovagramVoiceChangerUI",
    module_name = "NovagramVoiceChangerUI",
    srcs = glob(["Sources/**/*.swift"], allow_empty = True),
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
