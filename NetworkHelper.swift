//
//  NetworkHelper.swift
//  网络工具函数
//

import Foundation

/// 获取当前 WiFi 的局域网 IP 地址
func getWiFiIP() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
            let name = String(cString: interface.ifa_name)
            if name == "en0" {
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: buf)
            }
        }
    }
    freeifaddrs(ifaddr)
    return address
}
