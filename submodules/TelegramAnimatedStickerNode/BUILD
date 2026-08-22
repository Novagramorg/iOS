load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TelegramAnimatedStickerNode",
    module_name = "TelegramAnimatedStickerNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        # Fenixuz: min iOS 15 surfaces iOS-14/15 deprecations here; the APIs still work, so keep
        # every other warning fatal and downgrade only this group. Must follow -warnings-as-errors.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [
    	"//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/StickerResources:StickerResources",
        "//submodules/MediaResources:MediaResources",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/Tuples:Tuples",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/GZip:GZip",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/SoftwareVideo:SoftwareVideo",
    ],
    visibility = [
        "//visibility:public",
    ],
)
