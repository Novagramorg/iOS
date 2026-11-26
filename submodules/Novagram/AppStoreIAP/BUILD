load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Apple Review 3.1.1 compliance gate.
# Blocks BotCheckoutController for fiat-card subscriptions (Telegram Premium
# via @PremiumBot) on App Store builds. Shows a localized alert that points
# the reviewer at the native Telegram app on the App Store instead.
novagram_module(
    name = "NovagramAppStoreIAP",
    module_name = "NovagramAppStoreIAP",
    srcs = glob(["Sources/**/*.swift"], allow_empty = True),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
    visibility = ["//visibility:public"],
)
