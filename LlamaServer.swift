//
//  LlamaServer.swift
//  HTTP 服务器：提供 OpenAI-compatible /v1/chat/completions API
//
//  依赖：Swifter (通过 Swift Package Manager 引入)
//  https://github.com/httpswift/swifter
//

import Foundation
import Swifter

final class LlamaServer: ObservableObject {
    private var httpServer: HttpServer?
    private let engine = LlamaVisionEngine()

    @Published var isRunning = false
    @Published var lastLog = ""
    @Published var requestCount = 0

    private var modelPath: String
    private var mmprojPath: String
    private var port: UInt16

    init(modelPath: String, mmprojPath: String, port: UInt16 = 8080) {
        self.modelPath = modelPath
        self.mmprojPath = mmprojPath
        self.port = port
    }

    /// 更新配置（在启动前调用）
    func updateConfig(modelPath: String, mmprojPath: String, port: UInt16) {
        self.modelPath = modelPath
        self.mmprojPath = mmprojPath
        self.port = port
    }

    // MARK: - Server Control

    func start() {
        guard !engine.isLoaded else {
            log("模型已加载，直接启动服务器...")
            startHTTPServer()
            return
        }

        log("正在加载模型...")
        log("  Model: \(modelPath)")
        log("  MMProj: \(mmprojPath)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.engine.loadModel(modelPath: self.modelPath, mmprojPath: self.mmprojPath)
                DispatchQueue.main.async {
                    self.log("模型加载成功 ✅")
                    self.startHTTPServer()
                }
            } catch {
                DispatchQueue.main.async {
                    self.log("模型加载失败 ❌: \(error)")
                }
            }
        }
    }

    func stop() {
        httpServer?.stop()
        httpServer = nil
        engine.unload()
        DispatchQueue.main.async {
            self.isRunning = false
            self.log("服务器已停止")
        }
    }

    // MARK: - HTTP Server Setup

    private func startHTTPServer() {
        let server = HttpServer()

        // 健康检查
        server["/health"] = { _ in
            .ok(.json(["status": "ok", "model_loaded": self.engine.isLoaded]))
        }

        // OpenAI-compatible chat completions
        server["/v1/chat/completions"] = { [weak self] request in
            guard let self = self else {
                return .internalServerError(.json(["error": "server shutting down"]))
            }

            guard request.method == "POST" else {
                return .badRequest(.json(["error": "only POST supported"]))
            }

            // 解析 JSON body
            let bodyData = Data(request.body)
            do {
                let req = try JSONDecoder().decode(ChatCompletionRequest.self, from: bodyData)
                let (imageB64, prompt) = req.extractImageAndPrompt()

                self.log("[Request #\(self.requestCount + 1)] prompt=\(prompt.prefix(50))...")

                guard let imageB64 = imageB64 else {
                    return .badRequest(.json(["error": "no image provided"]))
                }

                // 执行推理
                let result = try self.engine.infer(
                    imageBase64: imageB64,
                    prompt: prompt,
                    maxTokens: Int32(req.max_tokens ?? 256)
                )

                self.requestCount += 1
                self.log("[Response] \(result.prefix(100))...")

                let response = ChatCompletionResponse(
                    id: "drone-\(self.requestCount)",
                    object: "chat.completion",
                    created: Int(Date().timeIntervalSince1970),
                    model: req.model ?? "qwen2.5-vl-3b",
                    choices: [
                        .init(
                            index: 0,
                            message: .init(role: "assistant", content: result),
                            finish_reason: "stop"
                        )
                    ]
                )

                let respData = try JSONEncoder().encode(response)
                return .ok(.data(respData, contentType: "application/json"))

            } catch let decodeErr as DecodingError {
                return .badRequest(.json(["error": "json decode failed: \(decodeErr)"]))
            } catch {
                return .internalServerError(.json(["error": "inference failed: \(error)"]))
            }
        }

        do {
            try server.start(in_port_t(port), forceIPv4: true, priority: .default)
            httpServer = server
            DispatchQueue.main.async {
                self.isRunning = true
                self.log("HTTP 服务器启动 ✅")
                self.log("  http://\(self.getWiFiAddress() ?? "127.0.0.1"):\(self.port)")
                self.log("  POST /v1/chat/completions")
                self.log("  GET  /health")
            }
        } catch {
            log("服务器启动失败 ❌: \(error)")
        }
    }

    // MARK: - Helpers

    private func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.lastLog += "[\(timestamp)] \(message)\n"
            print(message)
        }
    }

    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {  // WiFi interface on iOS
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
}
