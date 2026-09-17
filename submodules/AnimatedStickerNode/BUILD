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

swift_library(
    name = "AnimatedStickerNode",
    module_name = "AnimatedStickerNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ] + optimization_flags,
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/GZip:GZip",
        "//submodules/rlottie:RLottieBinding",
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

swift_library(
    name = "AnimatedStickerNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":AnimatedStickerNode",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
)

ios_test_runner(
    name = "AnimatedStickerNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "AnimatedStickerNodeTests",
    minimum_os_version = "15.0",
    runner = ":AnimatedStickerNodeTestRunner",
    deps = [
        ":AnimatedStickerNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
