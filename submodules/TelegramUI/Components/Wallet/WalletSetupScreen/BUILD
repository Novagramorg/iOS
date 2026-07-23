load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletSetupScreen",
    module_name = "WalletSetupScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
