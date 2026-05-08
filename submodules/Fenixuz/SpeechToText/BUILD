load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzSpeechToText",
    module_name = "FenixuzSpeechToText",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramAudio:TelegramAudio",
    ],
    visibility = [
        "//visibility:public",
    ],
)
