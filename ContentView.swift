//
//  ContentView.swift
//  TabView 主入口：模型管理 / 推理服务器 / 遥测监控
//

import SwiftUI

struct ContentView: View {
    @StateObject private var server = LlamaServer(
        modelPath: defaultModelPath(),
        mmprojPath: defaultMmprojPath(),
        port: 8080
    )
    @StateObject private var receiver = TelemetryReceiver()

    @State private var modelPath = defaultModelPath()
    @State private var mmprojPath = defaultMmprojPath()
    @State private var port = "8080"
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 模型管理
            ModelManagerView(modelPath: $modelPath, mmprojPath: $mmprojPath)
                .tabItem {
                    Label("模型", systemImage: "doc.badge.plus")
                }
                .tag(0)

            // Tab 2: 推理服务器
            ServerControlView(
                server: server,
                modelPath: $modelPath,
                mmprojPath: $mmprojPath,
                port: $port
            )
            .tabItem {
                Label("推理", systemImage: "cpu")
            }
            .tag(1)

            // Tab 3: 遥测监控
            TelemetryMonitorView(receiver: receiver)
                .tabItem {
                    Label("监控", systemImage: "video.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .onAppear {
            // 启动时尝试扫描默认路径
            refreshDefaults()
        }
    }

    // MARK: - Helpers

    private func refreshDefaults() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        // 自动查找最新的 gguf 和 mmproj
        if let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            let ggufs = files.filter { $0.lastPathComponent.hasSuffix(".gguf") }

            if let main = ggufs.first(where: { !$0.lastPathComponent.lowercased().contains("mmproj") }) {
                modelPath = main.path
            }
            if let mmproj = ggufs.first(where: { $0.lastPathComponent.lowercased().contains("mmproj") }) {
                mmprojPath = mmproj.path
            }
        }
    }
}

// MARK: - Default Paths

private func defaultModelPath() -> String {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent("qwen2.5-vl-3b-q4_k_m.gguf").path
}

private func defaultMmprojPath() -> String {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent("mmproj-qwen2.5-vl-3b-f16.gguf").path
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
