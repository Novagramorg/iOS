load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzProMessager",
    module_name = "FenixuzProMessager",
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
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/CallListUI:CallListUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/ComponentFlow",
        "//submodules/Fenixuz/Localization:FenixuzLocalization",
        "//submodules/Fenixuz/AutoProxy:FenixuzAutoProxy",
        "//submodules/Fenixuz/Brand:FenixuzBrand",
        "//submodules/Fenixuz/UnreadReminder:FenixuzUnreadReminder",
        "//submodules/Fenixuz/ChatLock:FenixuzChatLock",
        "//submodules/Fenixuz/SecretVault:FenixuzSecretVault",
    ],
    visibility = [
        "//visibility:public",
    ],
)
