load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RichTextEditorMediaView",
    module_name = "RichTextEditorMediaView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/InstantPageUI",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorUIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
