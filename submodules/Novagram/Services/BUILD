load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)

# Prebuilt NovagramServices SDK 1.2.0 (private repo Codingtech2/novagram-services-ios-sdk, release
# v1.2.0): STATIC xcframework, iOS device + simulator slices only, min iOS 15, library evolution.
# It holds the review login endpoint, the demo phone and the Statistics API URL + key (masked),
# so none of them is in this public repo. One import target for every Novagram module that uses
# it, so the static library is linked once. How to update it: the SDK's docs/INTEGRATION.md.
apple_static_xcframework_import(
    name = "NovagramServicesSDK",
    xcframework_imports = glob(
        ["Frameworks/NovagramServices.xcframework/**"],
        exclude = ["**/.DS_Store"],
    ),
    sdk_frameworks = [
        "StoreKit",
    ],
    visibility = [
        "//submodules/Novagram/AppleReview:__pkg__",
        "//submodules/Novagram/Analytics:__pkg__",
        "//submodules/Novagram/CurrencyRates:__pkg__",
    ],
)

# The SDK's SwiftUI views (NovagramServicesUI, same release). They link the core above and carry no
# copy of it, so both xcframeworks always come from one build. Only modules that show a view use it.
apple_static_xcframework_import(
    name = "NovagramServicesUISDK",
    xcframework_imports = glob(
        ["Frameworks/NovagramServicesUI.xcframework/**"],
        exclude = ["**/.DS_Store"],
    ),
    deps = [
        ":NovagramServicesSDK",
    ],
    visibility = [
        "//submodules/Novagram/Analytics:__pkg__",
        "//submodules/Novagram/CurrencyRates:__pkg__",
    ],
)
