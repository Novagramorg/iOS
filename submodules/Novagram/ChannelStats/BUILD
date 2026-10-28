load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)
load("//submodules/Novagram/Sponsored:novagram_environment.bzl", "novagram_environment_source")

# Prebuilt NovagramInsights + NovagramInsightsUI: STATIC xcframeworks, iOS device + simulator slices,
# built with library evolution. NovagramInsights (data layer) is iOS 15; NovagramInsightsUI (SwiftUI +
# Swift Charts) needs iOS 16, while the app's minimum is iOS 15 — so Charts and SwiftUI are WEAK-linked
# and every entry point is behind `#available(iOS 16, *)` (see NovagramChannelStatsEntry). Both import the
# NovagramAds SDK from the ad module (the same static library, linked once).
apple_static_xcframework_import(
    name = "NovagramInsightsSDK",
    xcframework_imports = glob(
        ["Frameworks/NovagramInsights.xcframework/**"],
        exclude = ["**/.DS_Store"],
    ),
    sdk_frameworks = [
        "AVFoundation",
        "Combine",
        "CoreMedia",
        "ImageIO",
        "Security",
    ],
    deps = [
        "//submodules/Novagram/Sponsored:NovagramAdsSDK",
    ],
    visibility = [
        "//visibility:private",
    ],
)

apple_static_xcframework_import(
    name = "NovagramInsightsUISDK",
    xcframework_imports = glob(
        ["Frameworks/NovagramInsightsUI.xcframework/**"],
        exclude = ["**/.DS_Store"],
    ),
    sdk_frameworks = [
        "PhotosUI",
        "UniformTypeIdentifiers",
    ],
    # These exist only from iOS 16 or later (Charts, PhotosPicker's CoreTransferable / _PhotosUI_SwiftUI, TipKit, and
    # the frameworks the newer SwiftUI / Swift module interfaces autolink) and the app runs on iOS 15: weak,
    # or dyld refuses to launch. UIUtilities and LightweightCodeRequirements are autolinked too but are not in
    # the simulator SDK (ld only warns for an autolink miss, but an explicit -weak_framework is an error).
    # SwiftUICore is autolinked as well, but ld refuses a direct link to it (only SwiftUI may re-export it).
    weak_sdk_frameworks = [
        "Charts",
        "SwiftUI",
        "CoreTransferable",
        "_PhotosUI_SwiftUI",
        "TipKit",
        "Symbols",
        "_LocationEssentials",
        "DataDetection",
        "DeveloperToolsSupport",
    ],
    deps = [
        ":NovagramInsightsSDK",
    ],
    visibility = [
        "//visibility:private",
    ],
)

# Environment from --define=novagramAdsEnvironment (development | production; empty = production).
novagram_environment_source(
    name = "NovagramChannelStatsEnvironment",
    enum_name = "NovagramChannelStatsGeneratedEnvironment",
)

swift_library(
    name = "NovagramChannelStats",
    module_name = "NovagramChannelStats",
    srcs = glob([
        "Sources/**/*.swift",
    ]) + [
        ":NovagramChannelStatsEnvironment",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":NovagramInsightsSDK",
        ":NovagramInsightsUISDK",
        "//submodules/Novagram/Sponsored:NovagramAdsSDK",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
    visibility = [
        "//visibility:public",
    ],
)
