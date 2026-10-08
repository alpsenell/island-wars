// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BattleCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BattleCore", targets: ["BattleCore"]),
    ],
    targets: [
        .target(name: "BattleCore"),
        .executableTarget(name: "balance-report", dependencies: ["BattleCore"]),
        .testTarget(name: "BattleCoreTests", dependencies: ["BattleCore"]),
    ]
)
