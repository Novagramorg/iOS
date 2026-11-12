// swift-tools-version:5.9
// The voice changer DSP as a standalone package, so it can move into its own public SDK repository later.
import PackageDescription

let package = Package(
    name: "NovagramVoiceDSP",
    products: [
        .library(name: "NovagramVoiceDSP", targets: ["NovagramVoiceDSP"]),
    ],
    targets: [
        .target(
            name: "NovagramVoiceDSP",
            path: "Sources/NovagramVoiceDSP",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "NovagramVoiceDSPTests",
            dependencies: ["NovagramVoiceDSP"],
            path: "Tests"
        ),
    ]
)
