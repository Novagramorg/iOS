load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

filegroup(
    name = "TONWalletKitResourceFiles",
    srcs = [
        "Sources/TONWalletKit/Resources/JS/inject.mjs",
        "Sources/TONWalletKit/Resources/JS/walletkit-ios-bridge.mjs",
    ] + glob([
        "Sources/TONWalletKit/JSCore/Polyfilling/Fetch/JS/*.js",
    ]),
)

plist_fragment(
    name = "TONWalletKitResourcesInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.TONWalletKitResources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>TONWalletKitResources</string>
    """
)

apple_resource_bundle(
    name = "TONWalletKitResources",
    infoplists = [
        ":TONWalletKitResourcesInfoPlist",
    ],
    resources = [
        ":TONWalletKitResourceFiles",
    ],
)

swift_library(
    name = "_BigInt",
    module_name = "_BigInt",
    srcs = glob([
        "Sources/BigInt/**/*.swift",
    ]),
    copts = [
        "-swift-version",
        "5",
        "-suppress-warnings",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "TONWalletKit",
    module_name = "TONWalletKit",
    srcs = glob([
        "BazelSupport/**/*.swift",
        "Sources/TONWalletKit/**/*.swift",
    ]),
    copts = [
        "-swift-version",
        "5",
        "-suppress-warnings",
    ],
    data = [
        ":TONWalletKitResources",
    ],
    deps = [
        ":_BigInt",
    ],
    visibility = [
        "//visibility:public",
    ],
)
