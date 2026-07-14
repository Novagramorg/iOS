load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletScreen",
    module_name = "WalletScreen",
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
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/ChatListHeaderComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/Gifts/InfoParagraphComponent",
        "//submodules/QrCodeUI",
        "//submodules/ContextUI",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramUI/Components/Wallet/WalletCardComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletTransactionItemComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
