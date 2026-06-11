// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RichTextEditor",
    platforms: [.iOS(.v17), .macOS(.v12)],
    products: [
        .library(name: "RichTextEditorCore", targets: ["RichTextEditorCore"]),
        .library(name: "RichTextEditorUIKit", targets: ["RichTextEditorUIKit"]),
    ],
    targets: [
        .target(name: "RichTextEditorCore"),
        .testTarget(name: "RichTextEditorCoreTests", dependencies: ["RichTextEditorCore"]),
        .target(name: "RichTextEditorUIKit", dependencies: ["RichTextEditorCore"],
                resources: [.process("Resources/Media.xcassets")]),
        .testTarget(name: "RichTextEditorUIKitTests", dependencies: ["RichTextEditorUIKit"]),
    ]
)
