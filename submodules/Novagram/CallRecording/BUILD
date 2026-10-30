load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# Local 1:1 call recording core (HOOKS.md, "Call recording"): the audio tap ring, the mixer, the AVAssetWriter
# recorder, the video compositor and the recordings folder. No UI and no strings.
# CallScreen and TelegramCallsUI depend on this module, so it must never depend on them, on Display,
# TelegramPresentationData, AccountContext or Postbox.
swift_library(
    name = "NovagramCallRecording",
    module_name = "NovagramCallRecording",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramVoip:TelegramVoip",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "NovagramCallRecordingTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        ":NovagramCallRecording",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        # Only for the notice text test; the core itself never depends on strings.
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
)

ios_test_runner(
    name = "NovagramCallRecordingTestRunner",
    device_type = "iPhone 17 Pro",
    os_version = "26.5",
)

ios_unit_test(
    name = "NovagramCallRecordingTests",
    minimum_os_version = "15.0",
    runner = ":NovagramCallRecordingTestRunner",
    deps = [
        ":NovagramCallRecordingTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
