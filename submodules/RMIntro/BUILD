load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

load("//build-system/bazel-utils:unique_directories.bzl", "unique_directories")

private_headers = glob([
    "Sources/**/*.h",
])

novagram_prebuilt_archive(
    name = "RMIntro_prebuilt_archive",
    library = "libRMIntro.a",
)

objc_library(
    name = "RMIntro",
    enable_modules = True,
    module_name = "RMIntro",
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-I{}/{}".format(package_name(), directory) for directory in unique_directories(private_headers)
    ] + [
        "-Werror",
        "-I{}/PublicHeaders/RMIntro".format(package_name()),
    ],
    deps = [
        "//submodules/LegacyComponents:LegacyComponents",
    ] + [":RMIntro_prebuilt_archive"],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "GLKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
