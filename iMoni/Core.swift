import Foundation
import AppKit

// MARK: - Enums

enum ConnectionStatus {
    case connected
    case disconnected
}

enum DisplayMode: String, CaseIterable {
    case systemUsage = "CPU/GPU"
    case memoryUsage = "Memory"
    case networkSpeed = "Network"
}

enum MonitorConstants {
    static let defaultInterval: TimeInterval = 1.0
    static let maxReasonableSpeed: Double = 1000.0
    static let networkQueueLabel = "com.imoni.network"
}

// MARK: - User Defaults

extension UserDefaults {
    var displayMode: DisplayMode {
        get {
            guard let raw = string(forKey: "displayMode"),
                  let mode = DisplayMode(rawValue: raw) else { return .networkSpeed }
            return mode
        }
        set { set(newValue.rawValue, forKey: "displayMode") }
    }

}

// MARK: - Formatting & Dispatch

/// 格式化网络速度，接收 **每秒兆字节数（MB/s）**，输出人类可读字符串（B/s ~ GB/s）。
/// 内部还原为 B/s 后做 1000 进制转换（网络单位传统十进制）。
/// - Parameter speedMBs: 以 MB/s 为单位的速度值（MonitorNetwork 产出）
func formatSpeed(_ speedMBs: Double) -> String {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var value = speedMBs * 1000 * 1000  // MB/s → B/s
    var unitIndex = 0
    while value >= 1000 && unitIndex < units.count - 1 {
        value /= 1000
        unitIndex += 1
    }
    if unitIndex == 0 {
        return "\(Int(value)) \(units[unitIndex])"
    }
    return String(format: "%.1f %@", value, units[unitIndex])
}

func mainQueue(_ block: @escaping () -> Void) {
    if Thread.isMainThread { block() }
    else { DispatchQueue.main.async(execute: block) }
}
