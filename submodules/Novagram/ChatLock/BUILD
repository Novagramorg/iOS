load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramChatLock",
    module_name = "NovagramChatLock",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
