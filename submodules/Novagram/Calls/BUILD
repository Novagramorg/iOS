load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Novagram extras for the 1:1 call screen (HOOKS.md, "Call weak signal and data saver"), and the app's one call
# recording center plus the frame adapter for the call recording SDK (HOOKS.md, "Call recording").
# CallScreen depends on this module, so it must never depend on CallScreen or TelegramCallsUI.
swift_library(
    name = "NovagramCalls",
    module_name = "NovagramCalls",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramVoip:TelegramVoip",
        "//submodules/Novagram/CallRecordingKit:NovagramCallRecordingCore",
    ],
    visibility = ["//visibility:public"],
)
