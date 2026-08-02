load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletContext",
    module_name = "WalletContext",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
      "//submodules/SSignalKit/SwiftSignalKit",
      "//submodules/TelegramCore",
      "//submodules/WalletContext/SwiftTonWalletKit:TONConnect",
      "//submodules/WalletContext/SwiftTonWalletKit:TONCore",
      "//submodules/WalletContext/SwiftTonWalletKit:TONCrypto",
      "//submodules/WalletContext/SwiftTonWalletKit:TONToncenter",
      "//submodules/WalletContext/SwiftTonWalletKit:TONWalletKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
