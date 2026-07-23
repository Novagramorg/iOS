load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletCollectibleItemComponent",
    module_name = "WalletCollectibleItemComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/PhotoResources",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/Wallet/WalletContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
