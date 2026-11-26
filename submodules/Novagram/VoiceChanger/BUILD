load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Voice changer (HOOKS.md, "Voice changer"): the settings, the developer gate and the recorder's effect wrapper over
# the C DSP in the VoiceChangerKit submodule. No UI here (the picker is in NovagramMessenger), so TelegramUI's recorder can depend on it.
novagram_module(
    name = "NovagramVoiceChanger",
    module_name = "NovagramVoiceChanger",
    srcs = glob(["Sources/**/*.swift"], allow_empty = True),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/Novagram/VoiceChangerKit:NovagramVoiceDSP",
    ],
    visibility = ["//visibility:public"],
)
