load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

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

swift_library(
    name = "WebProxyTransportTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":WebProxyTransport",
    ],
)

ios_test_runner(
    name = "WebProxyTransportTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "WebProxyTransportTests",
    minimum_os_version = "15.0",
    runner = ":WebProxyTransportTestRunner",
    deps = [
        ":WebProxyTransportTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
