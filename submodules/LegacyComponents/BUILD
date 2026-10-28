
load("@rules_cc//cc:objc_library.bzl", "objc_library")

filegroup(
    name = "LegacyComponentsResources",
    srcs = glob([
        "Resources/LegacyComponentsResources.bundle/**/*",
    ], exclude = ["Resources/LegacyComponentsResources.bundle/**/.*"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "LegacyComponentsAssets",
    srcs = glob(["LegacyImages.xcassets/**"]),
    visibility = ["//visibility:public"],
)


objc_library(
    name = "LegacyComponents",
    enable_modules = True,
    module_name = "LegacyComponents",
    srcs = glob([
        "Sources/*.m",
        "Sources/*.mm",
        "Sources/*.c",
        "Sources/*.cpp",
        "Sources/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-Werror",
        # Novagram: minimum_os_version 15.0 surfaces the iOS-14/15 deprecations in this legacy
        # module (UIButton edge insets, kUTType* constants, UIDocumentPickerMode). Every one of
        # them still works; modernising them would mean rewriting Telegram's legacy camera and
        # media-picker UI. Keep -Werror for everything else, exempt only deprecations.
        "-Wno-error=deprecated-declarations",
    ],
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/AppBundle:AppBundle",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKIt",
        "QuickLook",
        # TGMediaPickerGalleryVideoItemView uses MPVolumeView; declared here so a test bundle that links this
        # library without the app's other MediaPlayer clients still resolves it.
        "MediaPlayer",
        "CoreMotion",
    ],
    weak_sdk_frameworks = [
        "Vision",
        "PhotosUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
