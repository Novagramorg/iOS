load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "InstantPageUI",
    module_name = "InstantPageUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/CheckNode:CheckNode",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TextFormat:TextFormat",
        "//submodules/InvisibleInkDustNode:InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/MusicAlbumArtResources:MusicAlbumArtResources",
        "//submodules/SemanticStatusNode:SemanticStatusNode",
        "//submodules/LiveLocationPositionNode:LiveLocationPositionNode",
        "//submodules/MosaicLayout:MosaicLayout",
        "//submodules/LocationUI:LocationUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/LocationResources:LocationResources",
        "//submodules/UndoUI:UndoUI",
        "//submodules/TranslateUI:TranslateUI",
        "//submodules/Pasteboard",
        "//submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer",
        "//submodules/Tuples:Tuples",
        "//third-party/SwiftMath:SwiftMath",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramUI/Components/ShimmeringMask:ShimmeringMask",
        "//submodules/TelegramUI/Components/TextLoadingEffect:TextLoadingEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "InstantPageUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":InstantPageUI",
        "//submodules/Display:Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/TextFormat:TextFormatTests.
ios_test_runner(
    name = "InstantPageUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "InstantPageUITests",
    minimum_os_version = "13.0",
    runner = ":InstantPageUITestRunner",
    deps = [
        ":InstantPageUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
