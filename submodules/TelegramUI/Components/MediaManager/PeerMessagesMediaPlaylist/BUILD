load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "PeerMessagesMediaPlaylist",
    module_name = "PeerMessagesMediaPlaylist",
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/MusicAlbumArtResources",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
