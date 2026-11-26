load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

novagram_prebuilt_library(
    name = "ChatMessageDateAndStatusNode",
    module_name = "ChatMessageDateAndStatusNode",
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/LocalizedPeerData",
        "//submodules/Components/ReactionButtonListComponent",
        "//submodules/Components/ReactionImageComponent",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/TelegramUI/Components/StaticGlassBackground",
    ],
    visibility = [
        "//visibility:public",
    ],
)


# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/InstantPageUI:InstantPageUITests.

