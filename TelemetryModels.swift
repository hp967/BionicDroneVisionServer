//
//  TelemetryModels.swift
//  树莓派遥测数据模型 + AI 输出模型
//

import Foundation

/// 树莓派上传的完整遥测包
struct DroneTelemetry: Codable, Identifiable {
    let id = UUID()
    let timestamp: Double
    let state: String
    let battery: Double?
    let altitude: Double?
    let gps_sats: Int?
    let groundspeed: Double?
    let roll: Double?
    let pitch: Double?
    let yaw: Double?
    let trainer_mode: String?
    let takeover_requested: Bool?
    let ai_has_control: Bool?
    let alerts: String?

    /// 前端显示用格式化
    var batteryText: String {
        guard let v = battery else { return "--" }
        return String(format: "%.0f%%", v)
    }
    var altitudeText: String {
        guard let v = altitude else { return "--" }
        return String(format: "%.1f m", v)
    }
    var speedText: String {
        guard let v = groundspeed else { return "--" }
        return String(format: "%.1f m/s", v)
    }
    var attitudeText: String {
        guard let r = roll, let p = pitch else { return "--" }
        return String(format: "R:%.1f P:%.1f", r, p)
    }

    static var empty: DroneTelemetry {
        DroneTelemetry(timestamp: 0, state: "DISCONNECTED", battery: nil, altitude: nil,
                       gps_sats: nil, groundspeed: nil, roll: nil, pitch: nil, yaw: nil,
                       trainer_mode: nil, takeover_requested: nil, ai_has_control: nil, alerts: nil)
    }
}

/// 树莓派上传的图传帧
struct DroneFrame: Identifiable {
    let id = UUID()
    let timestamp: Date
    let imageData: Data
    let telemetry: DroneTelemetry
    let aiResult: String?

    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

/// 树莓派 → iPad 的 POST 请求体
struct DroneUploadRequest: Codable {
    let image_base64: String
    let telemetry: DroneTelemetry
    let ai_result: String?
}
