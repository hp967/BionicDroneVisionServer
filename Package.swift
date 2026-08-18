// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "BionicDroneVisionServer",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "BionicDroneVisionServer",
            targets: ["BionicDroneVisionServer"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "BionicDroneVisionServer",
            dependencies: [],
            path: "App"
        )
    ]
)
