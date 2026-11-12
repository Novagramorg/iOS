load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Voice changer (HOOKS.md, "Voice changer"): the settings, the developer gate and the recorder's effect wrapper over
# the C DSP in Core/. No UI here (the picker is in NovagramMessenger), so TelegramUI's recorder can depend on it.
swift_library(
    name = "NovagramVoiceChanger",
    module_name = "NovagramVoiceChanger",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Novagram/VoiceChanger/Core:NovagramVoiceDSP",
    ],
    visibility = ["//visibility:public"],
)
