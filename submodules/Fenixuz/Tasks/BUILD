load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzTasks",
    module_name = "FenixuzTasks",
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
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/TelegramUI/Components/Settings/QuickReplyNameAlertController:QuickReplyNameAlertController",
        "//submodules/AlertUI:AlertUI",
        "//submodules/Fenixuz/Localization:FenixuzLocalization",
    ],
    visibility = [
        "//visibility:public",
    ],
)
