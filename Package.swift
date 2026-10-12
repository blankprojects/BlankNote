// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlankNote",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BlankNote", targets: ["BlankNote"]),
        .library(name: "BlankNoteCore", targets: ["BlankNoteCore"])
    ],
    targets: [
        .target(name: "BlankNoteCore"),
        .executableTarget(name: "BlankNote", dependencies: ["BlankNoteCore"]),
        .testTarget(name: "BlankNoteCoreTests", dependencies: ["BlankNoteCore"])
    ]
)
