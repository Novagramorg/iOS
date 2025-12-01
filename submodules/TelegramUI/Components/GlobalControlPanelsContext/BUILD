load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GlobalControlPanelsContext",
    module_name = "GlobalControlPanelsContext",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramCallsUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
