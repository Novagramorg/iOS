load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzForeignUserBlock",
    module_name = "FenixuzForeignUserBlock",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
