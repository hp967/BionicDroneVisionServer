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
            path: ".",
            sources: [
                "BionicDroneVisionServerApp.swift",
                "ContentView.swift",
                "ModelManagerView.swift",
                "ServerControlView.swift",
                "TelemetryMonitorView.swift",
                "TelemetryReceiver.swift",
                "TelemetryModels.swift",
                "APIModels.swift",
                "NetworkHelper.swift",
                "LlamaServer.swift",
                "LlamaVisionEngine.swift"
            ],
            resources: [
                .process("BionicDroneVisionServer-Bridging-Header.h")
            ],
            publicHeadersPath: "spm-headers",
            cSettings: [
                .headerSearchPath("llama.cpp/include"),
                .headerSearchPath("llama.cpp/ggml/include"),
                .headerSearchPath("llama.cpp/src"),
                .define("GGML_METAL"),
                .define("GGML_OPENMP"),
            ]
        )
    ]
)
