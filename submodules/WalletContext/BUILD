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
      "//third-party/wallet-engine:WalletEngineFFI",
      "//submodules/SSignalKit/SwiftSignalKit",
      "//submodules/TelegramCore",
      "//submodules/WalletBackupCrypto",
    ],
    visibility = [
        "//visibility:public",
    ],
)
