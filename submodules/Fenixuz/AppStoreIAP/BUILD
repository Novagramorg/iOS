load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Apple Review 3.1.1 compliance gate.
# Blocks BotCheckoutController for fiat-card subscriptions (Telegram Premium
# via @PremiumBot) on App Store builds. Shows a localized alert that points
# the reviewer at the native Telegram app on the App Store instead.
swift_library(
    name = "FenixuzAppStoreIAP",
    module_name = "FenixuzAppStoreIAP",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Fenixuz/Localization:FenixuzLocalization",
    ],
    visibility = ["//visibility:public"],
)
