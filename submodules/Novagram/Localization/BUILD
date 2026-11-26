load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Novagram localization — central string table for all Novagram UI surfaces.
# Keep all hardcoded user-visible text OUT of Novagram controllers; instead
# reference NovagramL10n.<key> so the same call site renders in en / uz / ru / zh.
novagram_module(
    name = "NovagramLocalization",
    module_name = "NovagramLocalization",
    srcs = glob(["Sources/**/*.swift"], allow_empty = True),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = ["//visibility:public"],
)
