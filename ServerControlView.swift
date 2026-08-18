//
//  ServerControlView.swift
//  Vision 推理服务器控制面板
//

import SwiftUI

struct ServerControlView: View {
    @ObservedObject var server: LlamaServer
    @Binding var modelPath: String
    @Binding var mmprojPath: String
    @Binding var port: String

    @State private var showSettings = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 状态卡片
                statusCard

                // 设置面板
                if showSettings {
                    settingsPanel
                }

                // 快速操作
                quickActions

                // 日志
                logPanel
            }
            .padding()
        }
        .navigationTitle("推理服务器")
    }

    // MARK: - Subviews

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 14, height: 14)
                    .shadow(color: server.isRunning ? .green.opacity(0.4) : .red.opacity(0.4), radius: 4)

                Text(server.isRunning ? "运行中" : "已停止")
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("请求: \(server.requestCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if server.isRunning {
                        Text("模型已加载")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }

            if server.isRunning, let ip = getWiFiIP() {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                    Text("http://\(ip):\(port)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = "http://\(ip):\(port)"
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("服务器配置")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(showSettings ? "收起" : "展开") {
                    showSettings.toggle()
                }
                .font(.caption)
            }

            VStack(spacing: 10) {
                ConfigRow(icon: "doc", label: "Model", value: $modelPath, placeholder: "qwen2.5-vl-3b.gguf")
                ConfigRow(icon: "doc.text", label: "MMProj", value: $mmprojPath, placeholder: "mmproj.gguf")
                ConfigRow(icon: "number", label: "Port", value: $port, placeholder: "8080")
                    .keyboardType(.numberPad)
            }

            Button(action: toggleServer) {
                HStack {
                    Image(systemName: server.isRunning ? "stop.fill" : "play.fill")
                    Text(server.isRunning ? "停止服务器" : "启动服务器")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(server.isRunning ? Color.red.gradient : Color.green.gradient)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "arrow.clockwise", label: "重启", color: .orange) {
                if server.isRunning {
                    server.stop()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        startServer()
                    }
                }
            }
            ActionButton(icon: "trash", label: "清空日志", color: .gray) {
                server.lastLog = ""
            }
        }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("运行日志")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { server.lastLog = "" }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(server.lastLog.isEmpty ? "等待日志输出..." : server.lastLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(server.lastLog.isEmpty ? .secondary : .primary)
                }
                .frame(minHeight: 200, maxHeight: 400)
                .padding(10)
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)
                .onChange(of: server.lastLog) { _ in
                    // 自动滚动到底部（简化处理）
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleServer() {
        if server.isRunning {
            server.stop()
        } else {
            startServer()
        }
    }

    private func startServer() {
        server.updateConfig(
            modelPath: modelPath,
            mmprojPath: mmprojPath,
            port: UInt16(port) ?? 8080
        )
        server.start()
    }


}

// MARK: - Config Row

struct ConfigRow: View {
    let icon: String
    let label: String
    @Binding var value: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.secondary)
            Text(label)
                .frame(width: 60, alignment: .leading)
            TextField(placeholder, text: $value)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .keyboardType(keyboardType)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}
