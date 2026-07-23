load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletConnectScreen",
    module_name = "WalletConnectScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/SheetComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletCardComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
