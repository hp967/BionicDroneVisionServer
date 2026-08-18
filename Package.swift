// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "BionicDroneVisionServer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "BionicDroneVisionServer",
            targets: ["BionicDroneVisionServer"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BionicDroneVisionServer",
            dependencies: [],
            path: "App"
        )
    ]
)
