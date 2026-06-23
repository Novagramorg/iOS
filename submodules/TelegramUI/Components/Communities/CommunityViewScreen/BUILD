load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CommunityViewScreen",
    module_name = "CommunityViewScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AlertUI",
        "//submodules/AsyncDisplayKit",
        "//submodules/SearchUI",
        "//submodules/ChatListUI",
        "//submodules/ComponentFlow",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ResizableSheetComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Display",
        "//submodules/ItemListUI",
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/ChatListHeaderComponent",
        "//submodules/TelegramUI/Components/ChatListTitleView",
        "//submodules/TelegramUI/Components/Communities/CommunityPrivateChatScreen",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/ListItemComponentAdaptor",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/Stories/PeerListItemComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
