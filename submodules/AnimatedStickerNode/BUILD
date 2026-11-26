load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

config_setting(
    name = "debug_build",
    values = {
        "compilation_mode": "dbg",
    },
)

optimization_flags = select({
    ":debug_build": [
        #"-O",
    ],
    "//conditions:default": [],
})

novagram_prebuilt_library(
    name = "AnimatedStickerNode",
    module_name = "AnimatedStickerNode",
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/GZip:GZip",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/MediaResources:MediaResources",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AnimationCompression:AnimationCompression",
        "//submodules/Components/MetalImageView:MetalImageView",
        "//submodules/WebPBinding:WebPBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)



