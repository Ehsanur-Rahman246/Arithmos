// swift-tools-version:5.9
// Arithmos — Swift edition (Release 1). Standard library + Foundation only.
import PackageDescription

let package = Package(
    name: "arithmos",
    targets: [
        // All logic and the CLI layer live in the library (named differently from the
        // executable so the folders do not collide on case-insensitive file systems).
        .target(name: "ArithmosKit", path: "Sources/ArithmosKit"),
        // Thin executable: just calls ArithmosKit.arithmosRun.
        .executableTarget(name: "arithmos", dependencies: ["ArithmosKit"], path: "Sources/arithmos"),
        // XCTest target; uses @testable import, so nothing else needs to be public.
        .testTarget(name: "ArithmosKitTests", dependencies: ["ArithmosKit"], path: "Tests/ArithmosKitTests"),
    ]
)