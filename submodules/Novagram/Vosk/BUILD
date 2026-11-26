load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramVosk",
    module_name = "NovagramVosk",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    deps = [
        "//third-party/vosk:CVosk",
        "//third-party/ZipArchive:ZipArchive",
    ],
    visibility = [
        "//visibility:public",
    ],
)
