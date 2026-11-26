load("//submodules/Novagram:novagram_module.bzl", "novagram_prebuilt_archive", "novagram_prebuilt_library")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

novagram_prebuilt_library(
    name = "CameraLegacy",
    module_name = "CameraLegacy",
    deps = [
        "//submodules/Camera",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Utils/DeviceModel",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/AppBundle",
        "//submodules/GZip",
    ],
    data = [
        "//submodules/Camera:CameraBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
