load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzRoundVideoFromGallery",
    module_name = "FenixuzRoundVideoFromGallery",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        # Fenixuz: min iOS 15 surfaces iOS-14/15 deprecations here; the APIs still work, so keep
        # every other warning fatal and downgrade only this group. Must follow -warnings-as-errors.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/TelegramUI/Components/MediaEditor:MediaEditor",
    ],
    visibility = [
        "//visibility:public",
    ],
)
