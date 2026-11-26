load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Novagram currency rates page, opened from the Settings row that the hidden Developer switch
# "Show currency rates" turns on. It hosts the services SDK's SwiftUI converter (NovagramServicesUI:
# CurrencyCalculatorView + MultiCurrencyView) over the Central Bank rates from the SDK core.
novagram_module(
    name = "NovagramCurrencyRates",
    module_name = "NovagramCurrencyRates",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
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
