load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FenixuzContactsConsent",
    module_name = "FenixuzContactsConsent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        # Fenixuz: min iOS 15 surfaces iOS-14/15 deprecations here; the APIs still work, so keep
        # every other warning fatal and downgrade only this group. Must follow -warnings-as-errors.
        "-Wwarning",
        "DeprecatedDeclaration",
    ],
    deps = [],
    visibility = [
        "//visibility:public",
    ],
)
