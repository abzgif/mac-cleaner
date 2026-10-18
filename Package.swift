// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CleanMac",
            targets: ["CleanMac"]
        ),
        .library(
            name: "CleanMacCore",
            targets: ["CleanMacCore"]
        ),
        .executable(
            name: "CleanMacTestRunner",
            targets: ["CleanMacTestRunner"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CleanMacCore",
            dependencies: [],
            path: "Sources/CleanMacCore"
        ),
        .executableTarget(
            name: "CleanMac",
            dependencies: ["CleanMacCore"],
            path: "Sources/CleanMacApp"
        ),
        .executableTarget(
            name: "CleanMacTestRunner",
            dependencies: ["CleanMacCore"],
            path: "Tests/TestRunner"
        )
    ]
)
