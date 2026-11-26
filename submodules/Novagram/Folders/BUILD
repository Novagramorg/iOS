load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

# Novagram folder features in one place: Admin Folders (#47), recommended folders (#19, #21), the folder display
# style (#21) and the folder icon picker (#18). Device folders themselves live in TelegramCore
# (Sources/Novagram/NovagramDeviceChatListFilters.swift), next to the folder sync they hook into.
novagram_module(
    name = "NovagramFolders",
    module_name = "NovagramFolders",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/Novagram/Localization:NovagramLocalization",
    ],
    visibility = [
        "//visibility:public",
    ],
)
