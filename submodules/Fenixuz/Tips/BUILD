load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Fenixuz feature tips screen.
# Shows a scrollable list of all Fenixuz capabilities on first launch (post-login),
# and is reachable any time from FenixSettingsController ("Imkoniyatlar" row).
swift_library(
    name = "FenixuzTips",
    module_name = "FenixuzTips",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Fenixuz/Localization:FenixuzLocalization",
    ],
    visibility = ["//visibility:public"],
)
