load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

# The voice changer DSP: plain C, no Telegram module and no Apple framework, so it can move out into its own public
# package later (like CallRecordingKit). Used by the recorder (Swift, NovagramVoiceChanger) and by the call audio
# (TgVoipWebrtc). No external dependency: NovagramPitchShift.c is our trimmed copy of Sonic (Apache 2.0, CREDITS.md).
objc_library(
    name = "NovagramVoiceDSP",
    enable_modules = True,
    module_name = "NovagramVoiceDSP",
    srcs = [
        "Sources/NovagramVoiceDSP/NovagramVoiceDSP.c",
        "Sources/NovagramVoiceDSP/NovagramPitchShift.c",
        "Sources/NovagramVoiceDSP/NovagramPitchShift.h",
    ],
    hdrs = [
        "Sources/NovagramVoiceDSP/include/NovagramVoiceDSP/NovagramVoiceDSP.h",
    ],
    includes = [
        "Sources/NovagramVoiceDSP/include",
    ],
    copts = [
        "-O2",
        "-Isubmodules/Novagram/VoiceChanger/Core/Sources/NovagramVoiceDSP",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host test: every preset runs, tape speeds change the length as expected, nothing clips, and the call path keeps
# each buffer's size. `./build-input/bazel-<version> test //submodules/Novagram/VoiceChanger/Core:NovagramVoiceDSPTests`
cc_test(
    name = "NovagramVoiceDSPTests",
    srcs = [
        "Tests/NovagramVoiceDSPTests.c",
        "Sources/NovagramVoiceDSP/NovagramVoiceDSP.c",
        "Sources/NovagramVoiceDSP/include/NovagramVoiceDSP/NovagramVoiceDSP.h",
        "Sources/NovagramVoiceDSP/NovagramPitchShift.c",
        "Sources/NovagramVoiceDSP/NovagramPitchShift.h",
    ],
    copts = [
        "-Isubmodules/Novagram/VoiceChanger/Core/Sources/NovagramVoiceDSP",
        "-Isubmodules/Novagram/VoiceChanger/Core/Sources/NovagramVoiceDSP/include",
    ],
)
