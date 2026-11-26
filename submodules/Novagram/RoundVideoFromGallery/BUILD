load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramRoundVideoFromGallery",
    module_name = "NovagramRoundVideoFromGallery",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
        # Novagram: min iOS 15 surfaces iOS-14/15 deprecations here; the APIs still work, so keep
        # every other warning fatal and downgrade only this group. Must follow -warnings-as-errors.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [
        "//submodules/Novagram/ReviewPrompt:NovagramReviewPrompt",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        # Novagram: localized strings for the export-progress alert and the failure alert (2026-08-27).
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/TelegramUI/Components/MediaEditor:MediaEditor",
    ],
    visibility = [
        "//visibility:public",
    ],
)
