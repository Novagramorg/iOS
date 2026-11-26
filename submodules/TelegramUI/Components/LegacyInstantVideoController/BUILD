load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "LegacyInstantVideoController",
    module_name = "LegacyInstantVideoController",
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/MediaResources",
        "//submodules/LegacyComponents",
        "//submodules/AccountContext",
        "//submodules/LegacyUI",
        "//submodules/ImageCompression",
        "//submodules/LocalMediaResources",
        "//submodules/AppBundle",
        "//submodules/LegacyMediaPickerUI",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/ChatSendButtonRadialStatusNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
