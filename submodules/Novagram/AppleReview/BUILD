load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NovagramAppleReview",
    module_name = "NovagramAppleReview",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
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
