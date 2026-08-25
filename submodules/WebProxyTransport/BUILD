load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WebProxyTransport",
    module_name = "WebProxyTransport",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
