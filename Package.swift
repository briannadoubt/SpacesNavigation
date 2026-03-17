// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpacesNavigation",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpacesNavigation",
            targets: ["SpacesNavigation"]
        )
    ],
    targets: [
        .target(
            name: "SpacesNavigation"
        ),
        .testTarget(
            name: "SpacesNavigationTests",
            dependencies: ["SpacesNavigation"]
        )
    ]
)
