load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "WebWorkerShimResources",
    srcs = glob([
        "Resources/**/*.js",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "WebWorkerShimBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WebWorkerShim</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WebWorkerShim</string>
    """
)

apple_resource_bundle(
    name = "WebWorkerShimBundle",
    infoplists = [
        ":WebWorkerShimBundleInfoPlist",
    ],
    resources = [
        ":WebWorkerShimResources",
    ],
)

swift_library(
    name = "WebWorkerShim",
    module_name = "WebWorkerShim",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    data = [
        ":WebWorkerShimBundle",
    ],
    copts = [
        #"-warnings-as-errors",
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
