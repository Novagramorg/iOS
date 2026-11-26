load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
# SPDX-License-Identifier: GPL-2.0-or-later
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "NovagramCallRecordingCore",
    module_name = "NovagramCallRecordingCore",
    visibility = [
        "//visibility:public",
    ],
)

novagram_prebuilt_library(
    name = "NovagramCallRecordingUI",
    module_name = "NovagramCallRecordingUI",
    deps = [
        ":NovagramCallRecordingCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
