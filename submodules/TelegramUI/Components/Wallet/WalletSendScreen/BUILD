load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletSendScreen",
    module_name = "WalletSendScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/AttachmentUI",
        "//submodules/ComponentFlow",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/ContextUI",
        "//submodules/Display",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/AlertComponent/AlertInputFieldComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/GlassControls",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/QrCodeUI",
        "//submodules/TelegramUI/Components/Wallet/WalletContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
