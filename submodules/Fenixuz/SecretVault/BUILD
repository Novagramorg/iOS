load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzSecretVault",
    module_name = "FenixuzSecretVault",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/Fenixuz/ChatLock:FenixuzChatLock",
    ],
    visibility = [
        "//visibility:public",
    ],
)
