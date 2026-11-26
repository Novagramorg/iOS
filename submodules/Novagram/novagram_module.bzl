"""A Novagram module that builds from source or from a prebuilt binary.

Default: a normal swift_library from the module's sources (daily work).
With --define=novagram_sdk=binary: the module is imported from
<package>/Prebuilt/<cpu>/ (lib<Module>.a + <Module>.swiftmodule), so a checkout
without the sources still builds. scripts/novagram-sdk-export.sh fills Prebuilt/.

The prebuilt files must come from the same Telegram commit and the same Xcode as the
app build: a binary .swiftmodule is tied to both.
"""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_import", "swift_library")
load("@rules_cc//cc:cc_import.bzl", "cc_import")

_SIM = "//submodules/Novagram:ios_sim_arm64"
_BINARY = "//submodules/Novagram:novagram_sdk_binary"

def _prebuilt(module_name, file):
    return select({
        _SIM: ["Prebuilt/ios_sim_arm64/" + file],
        "//conditions:default": ["Prebuilt/ios_arm64/" + file],
    })

def novagram_module(name, module_name, srcs, deps = [], copts = [], data = [], visibility = None, **kwargs):
    swift_library(
        name = name + "_source",
        module_name = module_name,
        srcs = srcs,
        deps = deps,
        copts = copts,
        data = data,
        visibility = ["//visibility:private"],
        **kwargs
    )

    # Prebuilt/ is empty in a source checkout; allow_empty keeps loading happy there.
    native.filegroup(
        name = name + "_prebuilt_archive",
        srcs = _prebuilt(module_name, "lib" + module_name + ".a"),
    )
    native.filegroup(
        name = name + "_prebuilt_swiftmodule",
        srcs = _prebuilt(module_name, module_name + ".swiftmodule"),
    )
    swift_import(
        name = name + "_prebuilt",
        module_name = module_name,
        archives = [":" + name + "_prebuilt_archive"],
        swiftmodule = ":" + name + "_prebuilt_swiftmodule",
        deps = deps,
        # Resources (bundles, sounds) are not code: they ship with the binary too.
        data = data,
        visibility = ["//visibility:private"],
    )

    native.alias(
        name = name,
        actual = select({
            _BINARY: ":" + name + "_prebuilt",
            "//conditions:default": ":" + name + "_source",
        }),
        visibility = visibility,
    )

def novagram_prebuilt_library(name, module_name = None, deps = [], data = [], visibility = None):
    """A Telegram swift_library that carries our changes, imported from <package>/Prebuilt/<cpu>/.

    Only the public copy uses it: novagram_hidden_packages.py puts it in place of the package's
    swift_library and leaves the sources out. The dev repo always builds these packages from source.
    """
    module_name = module_name or name
    native.filegroup(
        name = name + "_prebuilt_archive",
        srcs = _prebuilt(module_name, "lib" + module_name + ".a"),
    )
    native.filegroup(
        name = name + "_prebuilt_swiftmodule",
        srcs = _prebuilt(module_name, module_name + ".swiftmodule"),
    )
    swift_import(
        name = name,
        module_name = module_name,
        archives = [":" + name + "_prebuilt_archive"],
        swiftmodule = ":" + name + "_prebuilt_swiftmodule",
        deps = deps,
        data = data,
        visibility = visibility,
    )

def novagram_prebuilt_archive(name, library):
    """The prebuilt archive of a Telegram objc_library that carries our changes (public copy only).

    alwayslink: an objc_library's objects are force-loaded too (-ObjC), categories need it.
    """
    cc_import(
        name = name,
        static_library = select({
            _SIM: "Prebuilt/ios_sim_arm64/" + library,
            "//conditions:default": "Prebuilt/ios_arm64/" + library,
        }),
        alwayslink = True,
    )
