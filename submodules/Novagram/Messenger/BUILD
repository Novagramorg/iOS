load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramMessenger",
    module_name = "NovagramMessenger",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        # Novagram: min iOS 15 surfaces iOS-14/15 deprecations here; the APIs still work, so keep
        # every other warning fatal and downgrade only this group. Must follow -warnings-as-errors.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [
        "//submodules/Novagram/StoryUnlock:NovagramStoryUnlock",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/ContextUI:ContextUI",
        "//submodules/CallListUI:CallListUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/ComponentFlow",
        "//submodules/Novagram/Localization:NovagramLocalization",
        "//submodules/Novagram/Search:NovagramSearch",
        "//submodules/Novagram/AutoProxy:NovagramAutoProxy",
        "//submodules/Novagram/Brand:NovagramBrand",
        "//submodules/Novagram/UnreadReminder:NovagramUnreadReminder",
        "//submodules/Novagram/ChatLock:NovagramChatLock",
        "//submodules/Novagram/SecretVault:NovagramSecretVault",
        "//submodules/Novagram/PremiumUnlock:NovagramPremiumUnlock",
    ],
    visibility = [
        "//visibility:public",
    ],
)
