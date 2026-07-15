// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SportRecord",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SportRecord", targets: ["SportRecord"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.16.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.0"),
    ],
    targets: [
        .target(
            name: "SportRecord",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SportRecordTests",
            dependencies: ["SportRecord"]
        ),
    ]
)
