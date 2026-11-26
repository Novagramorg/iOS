load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

novagram_prebuilt_library(
    name = "WalletContext",
    module_name = "WalletContext",
    deps = [
      "//third-party/wallet-engine:WalletEngineFFI",
      "//submodules/SSignalKit/SwiftSignalKit",
      "//submodules/TelegramCore",
      "//submodules/TelegramUIPreferences",
      "//submodules/WalletBackupCrypto",
      "//submodules/PasscodeCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)





