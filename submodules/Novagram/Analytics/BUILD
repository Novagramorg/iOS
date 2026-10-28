load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramAnalytics",
    module_name = "NovagramAnalytics",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/LottieSettings:LottieSettings",
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
