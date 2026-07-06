load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Fenixuz localization — central string table for all Fenixuz UI surfaces.
# Keep all hardcoded user-visible text OUT of Fenixuz controllers; instead
# reference FenixuzL10n.<key> so the same call site renders in en / uz / ru.
swift_library(
    name = "FenixuzLocalization",
    module_name = "FenixuzLocalization",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = ["//visibility:public"],
)
