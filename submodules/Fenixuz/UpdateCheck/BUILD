load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Fenixuz App Store update check.
# On post-login launch, queries iTunes Lookup API for uz.fenixuz.app
# and shows a one-per-session UIAlertController if a newer build is live.
swift_library(
    name = "FenixuzUpdateCheck",
    module_name = "FenixuzUpdateCheck",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Fenixuz/Localization:FenixuzLocalization",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = ["//visibility:public"],
)
