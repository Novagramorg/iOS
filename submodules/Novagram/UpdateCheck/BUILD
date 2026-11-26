load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Novagram App Store update check.
# On post-login launch, queries iTunes Lookup API for uz.fenixuz.app
# and shows a one-per-session UIAlertController if a newer build is live.
novagram_module(
    name = "NovagramUpdateCheck",
    module_name = "NovagramUpdateCheck",
    srcs = glob(["Sources/**/*.swift"], allow_empty = True),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = ["//visibility:public"],
)
