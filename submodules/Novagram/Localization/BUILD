load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Novagram localization — central string table for all Novagram UI surfaces.
# Keep all hardcoded user-visible text OUT of Novagram controllers; instead
# reference NovagramL10n.<key> so the same call site renders in en / uz / ru / zh.
swift_library(
    name = "NovagramLocalization",
    module_name = "NovagramLocalization",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = ["//visibility:public"],
)
