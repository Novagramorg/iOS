load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)
load(":novagram_environment.bzl", "novagram_environment_source")

# Prebuilt NovagramAds SDK 3.0 (ad serving v2, environment init): STATIC xcframework, iOS device + simulator slices,
# min iOS 15, built with library evolution. Source of truth: the NovagramAds repo (README "Ad serving v2").
# Private: only NovagramSponsored and NovagramChannelStats (submodules/Novagram/ChannelStats) import it, and NovagramSponsored is a dep of exactly TelegramUI, ChatListUI
# and GlobalControlPanelsContext (never TelegramCore / Postbox). It links statically into TelegramUIFramework,
# which some app extensions also load, but no extension code path calls it.
apple_static_xcframework_import(
    name = "NovagramAdsSDK",
    xcframework_imports = glob(
        ["Frameworks/NovagramAds.xcframework/**"],
        exclude = ["**/.DS_Store"],
    ),
    sdk_frameworks = [
        "CryptoKit",
        "DeviceCheck",
        "Security",
    ],
    visibility = [
        # The Insights module imports the same static library; one import target = no duplicate symbols.
        "//submodules/Novagram/ChannelStats:__pkg__",
    ],
)

# Environment from --define=novagramAdsEnvironment (development | production; empty = production).
novagram_environment_source(
    name = "NovagramSponsoredEnvironment",
    enum_name = "NovagramSponsoredGeneratedEnvironment",
)

# Dependency-light bridge for modules below NovagramSponsored in the graph (GalleryUI, chat bubble
# components): the `novagram:` check and the VIDEO-slot protocols. NovagramSponsored installs the
# implementation. No SDK, no Novagram deps — so it can never create a dependency cycle.
swift_library(
    name = "NovagramSponsoredBridge",
    module_name = "NovagramSponsoredBridge",
    srcs = glob([
        "Bridge/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "NovagramSponsored",
    module_name = "NovagramSponsored",
    srcs = glob([
        "Sources/**/*.swift",
    ]) + [
        ":NovagramSponsoredEnvironment",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":NovagramAdsSDK",
        ":NovagramSponsoredBridge",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/AppBundle:AppBundle",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ContextUI:ContextUI",
        "//submodules/UndoUI:UndoUI",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/Novagram/Messenger:NovagramMessenger",
    ],
    visibility = [
        "//visibility:public",
    ],
)
