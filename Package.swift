// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "EdexUI",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "EdexUI",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/EdexUI",
            resources: [
                .copy("Resources/AppIcon.icns"),
            ],
            swiftSettings: []
        ),
    ]
)
