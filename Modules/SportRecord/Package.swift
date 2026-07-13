// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SportRecord",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SportRecord", targets: ["SportRecord"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "SportRecord",
            dependencies: [.product(name: "Core", package: "Core")]
        ),
        .testTarget(
            name: "SportRecordTests",
            dependencies: ["SportRecord"]
        ),
    ]
)
