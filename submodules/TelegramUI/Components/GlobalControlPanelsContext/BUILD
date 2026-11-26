load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "GlobalControlPanelsContext",
    module_name = "GlobalControlPanelsContext",
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramStringFormatting",
        "//submodules/AccountContext",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramCallsUI",
        "//submodules/Display",
        "//submodules/UndoUI",
        "//submodules/Novagram/Sponsored:NovagramSponsored",
    ],
    visibility = [
        "//visibility:public",
    ],
)
