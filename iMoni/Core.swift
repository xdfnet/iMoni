import Foundation

// MARK: - Enums

enum DisplayMode: String, CaseIterable {
    case systemUsage = "CPU/GPU"
    case memoryUsage = "Memory"
    case networkSpeed = "Network"
    case stability = "Latency"
}

enum MonitorConstants {
    static let defaultInterval: TimeInterval = 1.0
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

/// 格式化 CPU/GPU 使用率（如 "CPU 50%"），宽度固定 3 位数字
func formatCPUPercent(_ percent: Double) -> String {
    String(format: "%3d%%", Int(round(percent)))
}

/// 格式化内存用量，返回 (显示文本, 百分比文本)
func formatMemoryGB(_ usedGB: Double, percent: Double) -> (top: String, bottom: String) {
    let used = Int(round(usedGB))
    let total = percent > 0 ? Int(round(usedGB / (percent / 100))) : 0
    return ("\(used)/\(total) GB", "PCT \(Int(round(percent)))%")
}

/// 格式化延迟，"23ms"（≥0）；"----"（无数据/超时）
func formatLatency(_ ms: Double) -> String {
    if ms < 0 { return "----" }
    if ms < 100 { return String(format: "%.1fms", ms) }
    return String(format: "%.0fms", ms)
}

/// 抖动，"±3ms"
func formatJitter(_ ms: Double) -> String {
    String(format: "±%.1fms", ms)
}

/// 丢包率，"0%"
func formatLossRate(_ rate: Double) -> String {
    String(format: "%.1f%%", rate * 100)
}

func mainQueue(_ block: @escaping () -> Void) {
    if Thread.isMainThread { block() }
    else { DispatchQueue.main.async(execute: block) }
}
