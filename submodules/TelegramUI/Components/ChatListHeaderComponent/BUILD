load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "ChatListHeaderComponent",
    module_name = "ChatListHeaderComponent",
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/ChatListTitleView",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/AppBundle",
        "//submodules/AsyncDisplayKit",
        "//submodules/AnimationUI",
        "//submodules/TelegramUI/Components/Stories/StoryPeerListComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/SearchUI",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/SideColumnLayout",
        "//submodules/TelegramUI/Components/NavigationBarComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
