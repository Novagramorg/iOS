load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Novagram currency rates page, opened from the Settings row that the hidden Developer switch
# "Show currency rates" turns on. It hosts the services SDK's SwiftUI converter (NovagramServicesUI:
# CurrencyCalculatorView + MultiCurrencyView) over the Central Bank rates from the SDK core.
swift_library(
    name = "NovagramCurrencyRates",
    module_name = "NovagramCurrencyRates",
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
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/Novagram/Services:NovagramServicesSDK",
        "//submodules/Novagram/Services:NovagramServicesUISDK",
    ],
    visibility = [
        "//visibility:public",
    ],
)
