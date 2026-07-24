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
        ),
        // Archive-reading logic shared by the Quick Look preview extension
        // (which compiles these same sources via project.yml). Kept UI-free so
        // it builds cross-platform and can be unit-tested here.
        .target(
            name: "GrizzlyArchiveKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "QuickLookExtension/Core"
        ),
        .testTarget(
            name: "GrizzlyTests",
            dependencies: [
                "Grizzly",
                "GrizzlyArchiveKit",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
