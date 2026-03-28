// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CortisolTracker",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "CortisolTracker",
            targets: ["CortisolTracker"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
        // NOTE: Presage SmartSpectraSwiftSDK is not available via SPM.
        // Add it manually via Xcode: File > Add Package or embed the .xcframework.
        // See PRESAGE_SDK_GUIDE.md for integration instructions.
    ],
    targets: [
        .target(
            name: "CortisolTracker",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
            ],
            path: "CortisolTracker"
        )
    ]
)
