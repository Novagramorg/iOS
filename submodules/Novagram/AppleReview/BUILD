load("//submodules/Novagram:novagram_module.bzl", "novagram_module")

novagram_module(
    name = "NovagramAppleReview",
    module_name = "NovagramAppleReview",
    srcs = glob([
        "Sources/**/*.swift",
    ], allow_empty = True),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Novagram/Services:NovagramServicesSDK",
    ],
    visibility = [
        "//visibility:public",
    ],
)
