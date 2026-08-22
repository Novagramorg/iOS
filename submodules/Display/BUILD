load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Display",
    module_name = "Display",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        # Fenixuz: with minimum_os_version at 15.0 the iOS-15 deprecations in this module become
        # visible, and -warnings-as-errors turns them into build failures. The APIs still behave
        # exactly as before (e.g. adjustsImageWhenHighlighted is only ignored when the button uses
        # UIButton.Configuration, which this code does not), so downgrade just that diagnostic
        # group back to a warning instead of rewriting working UI code. MUST come after
        # -warnings-as-errors — Swift applies these in order and the later flag wins.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [
    	"//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
    	"//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/AppBundle:AppBundle",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Markdown:Markdown",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
