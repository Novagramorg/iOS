load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzForwardEdit",
    module_name = "FenixuzForwardEdit",
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
    # Stand-alone on purpose: no other Fenixuz module is a dependency (owner request, 2026-09-25).
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ContextUI:ContextUI",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramUI/Components/TextFieldComponent:TextFieldComponent",
        "//submodules/TextFormat:TextFormat",
        "//submodules/PhotoResources:PhotoResources",
    ],
    visibility = [
        "//visibility:public",
    ],
)
