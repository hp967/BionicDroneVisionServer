// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BionicDroneVisionServer",
    platforms: [
        .iOS(.v16)
    ],
    targets: [
        .target(
            name: "BionicDroneVisionServer",
            path: ".",
            sources: [
                "BionicDroneVisionServerApp.swift",
                "ContentView.swift",
                "APIModels.swift",
                "LlamaServer.swift",
                "LlamaVisionEngine.swift",
                "ModelManagerView.swift",
                "NetworkHelper.swift",
                "ServerControlView.swift",
                "TelemetryModels.swift",
                "TelemetryMonitorView.swift",
                "TelemetryReceiver.swift"
            ],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .unsafeFlags(["-framework", "Accelerate"]),
                .unsafeFlags(["-F", "/usr/lib"]),
            ]
        )
    ]
)
