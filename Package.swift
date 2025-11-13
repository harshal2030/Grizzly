// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Grizzly",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Grizzly",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
