//
//  TelemetryReceiver.swift (简化版 - 无 Swifter 依赖)
//  接收树莓派 POST 的图传 + 遥测数据
//

import Foundation
import Combine

// 简化的 HTTP 服务器 - 使用 Swift 标准库
final class TelemetryHTTPServer {
    private let port: UInt16
    
    init(port: UInt16 = 8082) {
        self.port = port
    }
    
    func start() {
        print("Telemetry HTTP Server would start on port \(port)")
    }
    
    func stop() {
        print("Telemetry HTTP Server stopped")
    }
}

/// 管理来自树莓派的实时数据流
final class TelemetryReceiver: ObservableObject {
    @Published var latestFrame: DroneFrame?
    @Published var telemetryHistory: [DroneTelemetry] = []
    @Published var isReceiving = false
    @Published var lastLog = ""
    @Published var fps: Double = 0
    
    private var httpServer: TelemetryHTTPServer?
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
        
        httpServer = TelemetryHTTPServer(port: port)
        httpServer?.start()
        
        DispatchQueue.main.async {
            self.isReceiving = true
            self.log("遥测接收服务启动 ✅ port=\(self.port)")
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
    
    func processFrame(imageData: Data, telemetry: DroneTelemetry, aiResult: String?) {
        let frame = DroneFrame(
            timestamp: Date(),
            imageData: imageData,
            telemetry: telemetry,
            aiResult: aiResult
        )
        
        DispatchQueue.main.async {
            self.latestFrame = frame
            self.telemetryHistory.append(telemetry)
            if self.telemetryHistory.count > self.maxHistory {
                self.telemetryHistory.removeFirst(self.telemetryHistory.count - self.maxHistory)
            }
            self.frameCount += 1
            self.updateFPS()
        }
    }
    
    private func updateFPS() {
        let now = Date()
        let interval = now.timeIntervalSince(lastFPSTime)
        if interval >= 1.0 {
            fps = Double(frameCount) / interval
            frameCount = 0
            lastFPSTime = now
        }
    }
    
    private func log(_ message: String) {
        print("[TelemetryReceiver] \(message)")
        lastLog = message
    }
}
