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
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "SportRecord",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "SportRecordTests",
            dependencies: ["SportRecord"]
        ),
    ]
)
