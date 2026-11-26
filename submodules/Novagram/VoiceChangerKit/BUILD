load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
# SPDX-License-Identifier: GPL-2.0-or-later
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

novagram_prebuilt_archive(
    name = "NovagramVoiceDSP_prebuilt_archive",
    library = "libNovagramVoiceDSP.a",
)

objc_library(
    name = "NovagramVoiceDSP",
    enable_modules = True,
    module_name = "NovagramVoiceDSP",
    hdrs = [
        "Sources/NovagramVoiceDSP/include/NovagramVoiceDSP/NovagramVoiceDSP.h",
    ],
    includes = [
        "Sources/NovagramVoiceDSP/include",
    ],
    copts = [
        "-O2",
    ],
    visibility = [
        "//visibility:public",
    ],
    deps = [":NovagramVoiceDSP_prebuilt_archive"],
)

