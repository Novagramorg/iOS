load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "ChatMessageWebpageBubbleContentNode",
    module_name = "ChatMessageWebpageBubbleContentNode",
    deps = [
        "//submodules/Display",
        "//submodules/Novagram/Sponsored:NovagramSponsoredBridge",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramUIPreferences",
        "//submodules/TextFormat",
        "//submodules/AccountContext",
        "//submodules/WebsiteType",
        "//submodules/InstantPageUI",
        "//submodules/UrlHandling",
        "//submodules/GalleryData",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/WallpaperPreviewMedia",
        "//submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageAttachedContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatHistoryEntry",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
    ],
    visibility = [
        "//visibility:public",
    ],
)
