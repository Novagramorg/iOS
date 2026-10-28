load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramVosk",
    module_name = "NovagramVosk",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//third-party/vosk:CVosk",
        "//third-party/ZipArchive:ZipArchive",
    ],
    visibility = [
        "//visibility:public",
    ],
)
