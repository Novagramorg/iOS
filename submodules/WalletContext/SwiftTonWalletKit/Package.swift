// swift-tools-version: 6.0
//
// Native Swift WalletKit — a pure-Swift reimplementation of @ton/walletkit.

import PackageDescription

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
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        .target(
            name: "_TweetNaCl",
            exclude: ["README.md", "tweetnacl.c"],
            publicHeadersPath: "include"
        ),

        .target(name: "TONCore", dependencies: ["_BigInt"]),
        .target(name: "TONCrypto", dependencies: ["TONCore", "_TweetNaCl"]),
        .target(name: "TONContracts", dependencies: ["TONCore", "TONCrypto"]),
        .target(name: "TONToncenter", dependencies: ["TONCore", "TONCrypto"]),
        .target(name: "TONConnect", dependencies: ["TONCore", "TONCrypto"]),
        .target(
            name: "TONWalletKit",
            dependencies: ["TONCore", "TONCrypto", "TONContracts", "TONToncenter", "TONConnect"]
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
