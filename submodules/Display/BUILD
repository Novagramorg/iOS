load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_unit_test")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

novagram_prebuilt_library(
    name = "Display",
    module_name = "Display",
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


# The ASDK accessibility collector (`_ASDisplayViewAccessiblity.mm`) driven through Display's nodes and ListView, and
# the other tests that need a running app (`WindowTouchReleaseStateTests`: a recognizer's state machine).

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.


# DisplayAccessibilityTests need a running UIApplication (ListViewImpl's CADisplayLink is nil without one). The host
# links Display and AsyncDisplayKit itself so the test bundle does not carry a second copy: ASDK's `+load` creating a
# UIView while XCTest injects the bundle deadlocks in `+[UIScreen initialize]`.

plist_fragment(
    name = "DisplayAccessibilityTestHostInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.DisplayAccessibilityTestHost</string>
    <key>CFBundleName</key>
    <string>DisplayAccessibilityTestHost</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
    """
)

ios_application(
    name = "DisplayAccessibilityTestHost",
    testonly = True,
    bundle_id = "org.telegram.DisplayAccessibilityTestHost",
    families = ["iphone"],
    minimum_os_version = "15.0",
    infoplists = [":DisplayAccessibilityTestHostInfoPlist"],
    deps = [
        "//Tests/Common:Main",
        ":DisplayAccessibilityTestHostLib",
    ],
)

# The reused test simulator would otherwise keep the previous host build (and with it the previous Display/ASDK).
sh_binary(
    name = "UninstallDisplayAccessibilityTestHost",
    srcs = ["TestHost/uninstall_test_host.sh"],
)


