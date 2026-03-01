// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JTopGames",
    platforms: [
        .iOS(.v16)
    ],
    targets: [
        .executableTarget(
            name: "JTopGames",
            path: "Sources",
            resources: [
                .copy("Fonts"),
                .copy("Games")
            ]
        ),
        .testTarget(
            name: "JTopGamesTests",
            dependencies: ["JTopGames"],
            path: "Tests"
        )
    ]
)
