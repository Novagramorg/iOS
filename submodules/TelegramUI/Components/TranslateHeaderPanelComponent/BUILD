load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "TranslateHeaderPanelComponent",
    module_name = "TranslateHeaderPanelComponent",
    deps = [
        "//submodules/Novagram/PremiumUnlock:NovagramPremiumUnlock",
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/LocalizedPeerData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/MoreButtonNode",
        "//submodules/ContextUI",
        "//submodules/TranslateUI",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramNotices",
        "//submodules/PremiumUI",
        "//submodules/TelegramUI/Components/TranslationLanguagesContextMenuContent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
