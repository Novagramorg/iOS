load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Novagram feature tips screen.
# Shows a scrollable list of all Novagram capabilities on first launch (post-login),
# and is reachable any time from NovagramSettingsController ("Imkoniyatlar" row).
swift_library(
    name = "NovagramTips",
    module_name = "NovagramTips",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
    visibility = ["//visibility:public"],
)
