// swift-tools-version: 6.0
//
// Native Swift WalletKit — a pure-Swift reimplementation of @ton/walletkit.

import PackageDescription

/// Size-oriented codegen for every target in this package.
///
/// - `-Osize` trades a little speed for markedly less code, worth ~200 KB of arm64 binary.
///   Nothing here is on a hot path: hashing and Ed25519 are in C, and the rest is bounded
///   by network round trips.
/// - `-disable-reflection-metadata` drops field descriptors that only `Mirror`, `dump()`
///   and reflective `String(describing:)` on plain structs read. Nothing here uses them,
///   and every error type that gets printed conforms to `CustomStringConvertible`. ~50 KB.
///
/// These are `unsafeFlags`, which SwiftPM refuses to honour when this package is consumed
/// as a *versioned remote* dependency. Vendored or path-based consumers get them; anyone
/// depending by URL and tag must set the equivalent in their own build settings
/// (`SWIFT_OPTIMIZATION_LEVEL = -Osize`, plus the frontend flag in `OTHER_SWIFT_FLAGS`).
let sizeOptimized: [SwiftSetting] = [
    .unsafeFlags(
        ["-Osize", "-Xfrontend", "-disable-reflection-metadata"],
        .when(configuration: .release)
    )
]

let sizeOptimizedC: [CSetting] = [.unsafeFlags(["-Oz"], .when(configuration: .release))]

let package = Package(
    name: "TONWalletKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "TONCore", targets: ["TONCore"]),
        .library(name: "TONCrypto", targets: ["TONCrypto"]),
        .library(name: "TONContracts", targets: ["TONContracts"]),
        .library(name: "TONToncenter", targets: ["TONToncenter"]),
        .library(name: "TONConnect", targets: ["TONConnect"]),
        .library(name: "TONWalletKit", targets: ["TONWalletKit"]),
    ],
    targets: [
        .target(
            name: "_BigInt",
            exclude: ["LICENSE.md"],
            swiftSettings: [.swiftLanguageMode(.v5)] + sizeOptimized
        ),

        .target(
            name: "_TweetNaCl",
            exclude: ["README.md", "tweetnacl.c"],
            publicHeadersPath: "include",
            cSettings: sizeOptimizedC
        ),

        .target(name: "TONCore", dependencies: ["_BigInt"], swiftSettings: sizeOptimized),
        .target(name: "TONCrypto", dependencies: ["TONCore", "_TweetNaCl"], swiftSettings: sizeOptimized),
        .target(name: "TONContracts", dependencies: ["TONCore", "TONCrypto"], swiftSettings: sizeOptimized),
        .target(name: "TONToncenter", dependencies: ["TONCore", "TONCrypto"], swiftSettings: sizeOptimized),
        .target(name: "TONConnect", dependencies: ["TONCore", "TONCrypto"], swiftSettings: sizeOptimized),
        .target(
            name: "TONWalletKit",
            dependencies: ["TONCore", "TONCrypto", "TONContracts", "TONToncenter", "TONConnect"],
            swiftSettings: sizeOptimized
        ),

        .target(
            name: "TONTestVectors",
            path: "Tests/TONTestVectors",
            resources: [.copy("Vectors"), .copy("Fixtures")]
        ),

        .testTarget(name: "TONCoreTests", dependencies: ["TONCore", "TONTestVectors"]),
        .testTarget(name: "TONCryptoTests", dependencies: ["TONCrypto", "TONTestVectors"]),
        .testTarget(name: "TONContractsTests", dependencies: ["TONContracts", "TONTestVectors"]),
        .testTarget(
            name: "TONToncenterTests",
            dependencies: ["TONToncenter", "TONContracts", "TONTestVectors"]
        ),
        .testTarget(name: "TONConnectTests", dependencies: ["TONConnect", "TONTestVectors"]),
        .testTarget(name: "TONWalletKitTests", dependencies: ["TONWalletKit", "TONTestVectors"]),
    ],
    swiftLanguageModes: [.v6]
)
