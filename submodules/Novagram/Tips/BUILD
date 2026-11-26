load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Novagram feature tips screen.
# Shows a scrollable list of all Novagram capabilities on first launch (post-login),
# and is reachable any time from NovagramSettingsController ("Imkoniyatlar" row).
novagram_module(
    name = "NovagramTips",
    module_name = "NovagramTips",
    srcs = glob(["Sources/**/*.swift"], allow_empty = True),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
    visibility = ["//visibility:public"],
)
