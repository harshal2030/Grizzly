// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZipViewer",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "ZipViewer",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
