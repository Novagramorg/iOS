load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzChatLock",
    module_name = "FenixuzChatLock",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
