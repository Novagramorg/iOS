load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramSpeechToText",
    module_name = "NovagramSpeechToText",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/Novagram/Vosk:NovagramVosk",
    ],
    visibility = [
        "//visibility:public",
    ],
)
