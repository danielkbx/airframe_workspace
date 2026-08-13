// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ScreenshotFixtures",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "screenshot-fixtures", targets: ["ScreenshotFixtures"])],
    dependencies: [
        .package(path: "../../Airframe/Packages/AirframeContainer"),
        .package(path: "../../Airframe/Packages/BlackboxAnalysis"),
        .package(path: "../../Airframe/Packages/BlackboxReader"),
    ],
    targets: [
        .executableTarget(name: "ScreenshotFixtures", dependencies: ["AirframeContainer", "BlackboxAnalysis", "BlackboxReader"])
    ]
)
