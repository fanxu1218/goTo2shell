// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoToShell",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "GoToShell", targets: ["GoToShell"])],
    targets: [
        .target(name: "GoToShellCore"),
        .executableTarget(name: "GoToShell", dependencies: ["GoToShellCore"]),
        .testTarget(name: "GoToShellCoreTests", dependencies: ["GoToShellCore"])
    ]
)
