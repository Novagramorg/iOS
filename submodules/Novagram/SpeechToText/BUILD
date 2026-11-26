load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramSpeechToText",
    module_name = "NovagramSpeechToText",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Novagram/ReviewPrompt:NovagramReviewPrompt",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramAudio:TelegramAudio",
        "//submodules/Novagram/Vosk:NovagramVosk",
    ],
    visibility = [
        "//visibility:public",
    ],
)
