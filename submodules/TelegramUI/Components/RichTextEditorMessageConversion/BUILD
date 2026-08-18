load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "RichTextEditorMessageConversion",
    module_name = "RichTextEditorMessageConversion",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "RichTextEditorMessageConversionTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":RichTextEditorMessageConversion",
        "//submodules/TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
    ],
)

# The default ios_test_runner picks an invalid device and the test process exits 15 — pin it to a
# real device/OS, mirroring //submodules/TextFormat:TextFormatTestRunner. See CLAUDE.md.
ios_test_runner(
    name = "RichTextEditorMessageConversionTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "RichTextEditorMessageConversionTests",
    minimum_os_version = "13.0",
    runner = ":RichTextEditorMessageConversionTestRunner",
    deps = [
        ":RichTextEditorMessageConversionTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
