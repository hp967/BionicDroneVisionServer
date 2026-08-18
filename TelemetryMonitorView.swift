//
//  TelemetryMonitorView.swift
//  遥测监控：接收树莓派图传 + 飞行数据实时显示
//

import SwiftUI

struct TelemetryMonitorView: View {
    @ObservedObject var receiver: TelemetryReceiver
    @State private var showImageFullscreen = false
    @State private var selectedPort = String(receiver.port)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 连接状态 + 图传
                    videoSection

                    // 遥测数据面板
                    telemetryGrid

                    // AI 输出
                    aiResultSection

                    // 控制按钮
                    controlSection

                    // 接收日志
                    logSection
                }
                .padding()
            }
            .navigationTitle("遥测监控")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(receiver.isReceiving ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(receiver.isReceiving ? "在线" : "离线")
                            .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $showImageFullscreen) {
                if let frame = receiver.latestFrame, let uiImage = frame.uiImage {
                    FullscreenImageView(image: uiImage, telemetry: frame.telemetry)
                }
            }
        }
    }

    // MARK: - Video Section

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("实时图传")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if receiver.fps > 0 {
                    Text(String(format: "%.1f FPS", receiver.fps))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .aspectRatio(4/3, contentMode: .fit)

                if let frame = receiver.latestFrame, let uiImage = frame.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit
                        .cornerRadius(16)
                        .onTapGesture {
                            showImageFullscreen = true
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("等待图传数据...")
                            .foregroundColor(.gray)
                        Text("树莓派 POST → http://iPadIP:\(selectedPort)/drone/upload")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 叠加遥测信息
                if let frame = receiver.latestFrame {
                    VStack {
                        HStack {
                            TelemetryBadge(icon: "battery.100", text: frame.telemetry.batteryText, color: .green)
                            TelemetryBadge(icon: "arrow.up", text: frame.telemetry.altitudeText, color: .blue)
                            Spacer()
                        }
                        .padding(8)
                        Spacer()
                        HStack {
                            TelemetryBadge(icon: "location", text: frame.telemetry.speedText, color: .orange)
                            TelemetryBadge(icon: "gyroscope", text: frame.telemetry.attitudeText, color: .purple)
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
        }
    }

    // MARK: - Telemetry Grid

    private var telemetryGrid: some View {
        let telem = receiver.latestFrame?.telemetry ?? .empty

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            TelemetryCard(title: "飞行状态", value: telem.state, icon: "airplane", color: stateColor(telem.state))
            TelemetryCard(title: "电量", value: telem.batteryText, icon: "battery.100", color: batteryColor(telem.battery))
            TelemetryCard(title: "高度", value: telem.altitudeText, icon: "arrow.up", color: .blue)
            TelemetryCard(title: "地速", value: telem.speedText, icon: "location", color: .orange)
            TelemetryCard(title: "GPS 卫星", value: telem.gps_sats != nil ? "\(telem.gps_sats!)" : "--", icon: "satellite", color: .cyan)
            TelemetryCard(title: "教练模式", value: telem.trainer_mode ?? "--", icon: "switch.2", color: .purple)
        }
    }

    // MARK: - AI Result

    private var aiResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI 推理结果")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }

            if let result = receiver.latestFrame?.aiResult, !result.isEmpty {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                Text("等待 AI 输出...")
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("接收端口")
                    .foregroundColor(.secondary)
                Spacer()
                TextField("8082", text: $selectedPort)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }

            HStack(spacing: 12) {
                Button(action: {
                    receiver.port = UInt16(selectedPort) ?? 8082
                    receiver.start()
                }) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("开始接收")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(receiver.isReceiving ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(receiver.isReceiving)

                Button(action: { receiver.stop() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("停止")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }

            Button(action: { receiver.clearHistory() }) {
                Label("清空历史", systemImage: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("接收日志")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { receiver.lastLog = "" }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
            }

            ScrollView {
                Text(receiver.lastLog.isEmpty ? "等待数据..." : receiver.lastLog)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120, maxHeight: 200)
            .padding(10)
            .background(Color.black.opacity(0.05))
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "NORMAL": return .green
        case "RTL": return .red
        case "DECELERATE", "HOVER", "ALERT": return .orange
        default: return .gray
        }
    }

    private func batteryColor(_ battery: Double?) -> Color {
        guard let v = battery else { return .gray }
        if v > 50 { return .green }
        if v > 25 { return .orange }
        return .red
    }
}

// MARK: - Telemetry Card

struct TelemetryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Telemetry Badge

struct TelemetryBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .background(color.opacity(0.3))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

// MARK: - Fullscreen Image

struct FullscreenImageView: View {
    let image: UIImage
    let telemetry: DroneTelemetry
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit
                    .ignoresSafeArea()
            }
            .navigationTitle("图传详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
