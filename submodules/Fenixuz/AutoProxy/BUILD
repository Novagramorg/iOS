load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "FenixuzAutoProxyResourceFiles",
    srcs = glob([
        "Resources/**/*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "FenixuzAutoProxyResourcesInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>uz.fenixuz.app.FenixuzAutoProxyResources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>FenixuzAutoProxyResources</string>
    """
)

apple_resource_bundle(
    name = "FenixuzAutoProxyResources",
    infoplists = [
        ":FenixuzAutoProxyResourcesInfoPlist",
    ],
    resources = [
        ":FenixuzAutoProxyResourceFiles",
    ],
)

swift_library(
    name = "FenixuzAutoProxy",
    module_name = "FenixuzAutoProxy",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":FenixuzAutoProxyResources",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
