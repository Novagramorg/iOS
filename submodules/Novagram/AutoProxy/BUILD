load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

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

novagram_module(
    name = "NovagramAutoProxy",
    module_name = "NovagramAutoProxy",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
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
