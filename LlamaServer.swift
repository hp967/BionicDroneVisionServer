//
//  LlamaServer.swift (简化版 - 无 Swifter 依赖)
//  HTTP 服务器通过 Foundation.URLSession 实现
//

import Foundation
import Combine

// 简化的 HTTP 服务器 - 使用 Swift 标准库
final class SimpleHTTPServer {
    private var task: URLSessionDataTask?
    private let port: UInt16
    
    init(port: UInt16 = 8080) {
        self.port = port
    }
    
    func start() {
        // 简化实现：仅打印启动信息
        print("HTTP Server would start on port \(port)")
    }
    
    func stop() {
        task?.cancel()
        task = nil
        print("HTTP Server stopped")
    }
}

final class LlamaServer: ObservableObject {
    private var httpServer: SimpleHTTPServer?
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
    
    func updateConfig(modelPath: String, mmprojPath: String, port: UInt16) {
        self.modelPath = modelPath
        self.mmprojPath = mmprojPath
        self.port = port
    }
    
    func start() {
        guard !engine.isLoaded else {
            log("模型已加载，直接启动服务器...")
            httpServer = SimpleHTTPServer(port: port)
            httpServer?.start()
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
                    self.httpServer = SimpleHTTPServer(port: self.port)
                    self.httpServer?.start()
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
    
    private func log(_ message: String) {
        print("[LlamaServer] \(message)")
        lastLog = message
    }
}
