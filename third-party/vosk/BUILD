load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)

# Prebuilt static Vosk C library (Kaldi-based offline speech recognition).
# Mirrors third-party/recaptcha/BUILD — the fork's existing prebuilt xcframework import.
apple_static_xcframework_import(
    name = "libvosk",
    xcframework_imports = glob(
        ["libvosk.xcframework/**"],
        exclude = ["**/.DS_Store"],
    ),
    features = [
    ],
    visibility = [
        "//visibility:public",
    ],
)

# vosk_api.h ships with no modulemap, so wrap it in a header-only objc_library with a
# module_name — Bazel synthesizes the modulemap and FenixuzVosk can then `import CVosk`.
# Same C-header-to-Swift bridge trick used elsewhere in this tree.
objc_library(
    name = "CVosk",
    module_name = "CVosk",
    hdrs = [
        "include/vosk_api.h",
    ],
    includes = [
        "include",
    ],
    deps = [
        ":libvosk",
    ],
    visibility = [
        "//visibility:public",
    ],
)
