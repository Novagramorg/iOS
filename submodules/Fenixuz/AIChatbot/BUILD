load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# NOTE: this target is intentionally NOT linked into the App Store build.
# The dep was removed from submodules/TelegramUI/BUILD (line ~53) and the
# consumer code is commented out in TelegramRootController.swift.
# Module + sources are kept here so the AI tab can be revived later
# without re-implementing it. See P1-4 in the publish-readiness audit.
swift_library(
    name = "FenixuzAIChatbot",
    module_name = "FenixuzAIChatbot",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
