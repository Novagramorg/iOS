load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramAnalytics",
    module_name = "NovagramAnalytics",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Novagram/ReviewPrompt:NovagramReviewPrompt",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/Novagram/Services:NovagramServicesSDK",
        "//submodules/Novagram/Services:NovagramServicesUISDK",
    ],
    visibility = [
        "//visibility:public",
    ],
)
