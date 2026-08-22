load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzProMessager",
    module_name = "FenixuzProMessager",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        # Fenixuz: min iOS 15 surfaces iOS-14/15 deprecations here; the APIs still work, so keep
        # every other warning fatal and downgrade only this group. Must follow -warnings-as-errors.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [
        "//submodules/Fenixuz/StoryUnlock:FenixuzStoryUnlock",
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
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/PhoneNumberFormat:PhoneNumberFormat",
        "//submodules/OverlayStatusController:OverlayStatusController",
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
        "//submodules/Fenixuz/PremiumUnlock:FenixuzPremiumUnlock",
    ],
    visibility = [
        "//visibility:public",
    ],
)
