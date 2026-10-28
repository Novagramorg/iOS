load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "NovagramAutoProxyResourceFiles",
    # Bazel 9 rejects an empty glob; AutoProxy has no resources yet.
    srcs = glob([
        "Resources/**/*",
    ], allow_empty = True),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "NovagramAutoProxyResourcesInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>uz.fenixuz.app.FenixuzAutoProxyResources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>NovagramAutoProxyResources</string>
    """
)

apple_resource_bundle(
    name = "NovagramAutoProxyResources",
    infoplists = [
        ":NovagramAutoProxyResourcesInfoPlist",
    ],
    resources = [
        ":NovagramAutoProxyResourceFiles",
    ],
)

swift_library(
    name = "NovagramAutoProxy",
    module_name = "NovagramAutoProxy",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":NovagramAutoProxyResources",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
