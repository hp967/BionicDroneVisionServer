//
//  TelemetryReceiver.swift
//  接收树莓派 POST 的图传 + 遥测数据
//

import Foundation
import Combine
import Swifter

/// 管理来自树莓派的实时数据流
final class TelemetryReceiver: ObservableObject {
    @Published var latestFrame: DroneFrame?
    @Published var telemetryHistory: [DroneTelemetry] = []
    @Published var isReceiving = false
    @Published var lastLog = ""
    @Published var fps: Double = 0

    private var httpServer: HttpServer?
    private var frameCount = 0
    private var lastFPSTime = Date()
    private let maxHistory = 300  // 保留最近 300 条遥测

    var port: UInt16 = 8082  // 默认接收端口（与推理服务器 8080 区分）

    // MARK: - Server Control

    func start() {
        guard httpServer == nil else {
            log("接收服务已在运行")
            return
        }

        let server = HttpServer()

        // 接收树莓派上传的图传 + 遥测
        server["/drone/upload"] = { [weak self] request in
            guard let self = self else {
                return .internalServerError(.json(["error": "receiver down"]))
            }
            guard request.method == "POST" else {
                return .badRequest(.json(["error": "POST only"]))
            }

            let bodyData = Data(request.body)
            do {
                let req = try JSONDecoder().decode(DroneUploadRequest.self, from: bodyData)

                guard let imageData = Data(base64Encoded: req.image_base64, options: .ignoreUnknownCharacters) else {
                    return .badRequest(.json(["error": "invalid image base64"]))
                }

                // ai_result 来自树莓派回传的 AI 推理结果文本
                let frame = DroneFrame(
                    timestamp: Date(),
                    imageData: imageData,
                    telemetry: req.telemetry,
                    aiResult: req.ai_result  // 可能为 nil（推理失败时）
                )

                DispatchQueue.main.async {
                    self.latestFrame = frame
                    self.telemetryHistory.append(req.telemetry)
                    if self.telemetryHistory.count > self.maxHistory {
                        self.telemetryHistory.removeFirst(self.telemetryHistory.count - self.maxHistory)
                    }
                    self.frameCount += 1
                    self.updateFPS()
                }

                return .ok(.json(["status": "ok", "frame_id": self.frameCount]))

            } catch {
                return .badRequest(.json(["error": "decode failed: \(error)"]))
            }
        }

        // 健康检查
        server["/drone/health"] = { _ in
            .ok(.json(["status": "ok", "mode": "telemetry_receiver"]))
        }

        do {
            try server.start(in_port_t(port), forceIPv4: true, priority: .default)
            httpServer = server
            DispatchQueue.main.async {
                self.isReceiving = true
                self.log("遥测接收服务启动 ✅ port=\(self.port)")
            }
        } catch {
            log("遥测接收服务启动失败 ❌: \(error)")
        }
    }

    func stop() {
        httpServer?.stop()
        httpServer = nil
        DispatchQueue.main.async {
            self.isReceiving = false
            self.fps = 0
            self.log("遥测接收服务已停止")
        }
    }

    func clearHistory() {
        telemetryHistory.removeAll()
        latestFrame = nil
        frameCount = 0
        log("历史数据已清空")
    }

    // MARK: - Helpers

    private func updateFPS() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastFPSTime)
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastFPSTime = now
        }
    }

    private func log(_ message: String) {
        DispatchQueue.main.async {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.lastLog += "[\(ts)] \(message)\n"
        }
    }
}
