load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramForeignUserBlock",
    module_name = "NovagramForeignUserBlock",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AppBundle:AppBundle",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUI/Components/NavigationBarComponent:NavigationBarComponent",
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
    visibility = [
        "//visibility:public",
    ],
)
