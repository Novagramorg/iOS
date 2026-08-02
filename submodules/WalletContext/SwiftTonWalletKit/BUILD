load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

native_swift_copts = [
    "-swift-version",
    "6",
    "-warnings-as-errors",
]

swift_library(
    name = "_BigInt",
    module_name = "_BigInt",
    srcs = glob([
        "Sources/_BigInt/**/*.swift",
    ]),
    copts = [
        "-swift-version",
        "5",
        "-suppress-warnings",
    ],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "_TONCryptoBoringSSL",
    module_name = "_TONCryptoBoringSSL",
    enable_modules = True,
    srcs = [
        "Sources/_TONCryptoBoringSSL/ton_crypto_boringssl.c",
    ],
    hdrs = [
        "Sources/_TONCryptoBoringSSL/include/ton_crypto_boringssl.h",
    ],
    includes = [
        "Sources/_TONCryptoBoringSSL/include",
    ],
    copts = [
        "-Werror",
    ],
    deps = [
        "//third-party/boringssl:crypto",
    ],
)

swift_library(
    name = "TONCore",
    module_name = "TONCore",
    srcs = glob([
        "Sources/TONCore/**/*.swift",
    ]),
    copts = native_swift_copts,
    deps = [
        ":_BigInt",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "TONCrypto",
    module_name = "TONCrypto",
    srcs = glob([
        "Sources/TONCrypto/**/*.swift",
    ], exclude = [
        "Sources/TONCrypto/TweetNaClProvider.swift",
    ]),
    copts = native_swift_copts,
    deps = [
        ":TONCore",
        ":_TONCryptoBoringSSL",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "TONContracts",
    module_name = "TONContracts",
    srcs = glob([
        "Sources/TONContracts/**/*.swift",
    ]),
    copts = native_swift_copts,
    deps = [
        ":TONCore",
        ":TONCrypto",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "TONToncenter",
    module_name = "TONToncenter",
    srcs = glob([
        "Sources/TONToncenter/**/*.swift",
    ]),
    copts = native_swift_copts,
    deps = [
        ":TONCore",
        ":TONCrypto",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "TONConnect",
    module_name = "TONConnect",
    srcs = glob([
        "Sources/TONConnect/**/*.swift",
    ]),
    copts = native_swift_copts,
    deps = [
        ":TONCore",
        ":TONCrypto",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "TONWalletKit",
    module_name = "TONWalletKit",
    srcs = glob([
        "Sources/TONWalletKit/**/*.swift",
    ]),
    copts = native_swift_copts,
    deps = [
        ":TONConnect",
        ":TONContracts",
        ":TONCore",
        ":TONCrypto",
        ":TONToncenter",
    ],
    visibility = ["//visibility:public"],
)
