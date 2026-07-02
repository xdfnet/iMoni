import Foundation

// MARK: - Enums

enum DisplayMode: String, CaseIterable {
    case cpuUsage = "CPU"
    case gpuUsage = "GPU"
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

/// 格式化网络速度，接收 **每秒字节数（bytes/s）**，输出人类可读字符串（KB/s ~ GB/s）。
/// 1000 进制（网络单位传统十进制），整数与 1 位小数按值切换。
/// - Parameter bytes: 以 bytes/s 为单位的速度值（MonitorNetwork 产出）
func formatSpeed(_ bytes: Int64) -> String {
    switch bytes {
    case 0:
        return "0 KB/s"
    case 1..<1_000_000: // 1 B/s ~ 999,999 B/s → 整数 KB/s
        return "\(bytes / 1_000) KB/s"
    case 1_000_000..<100_000_000: // 1 ~ 99.9 MB/s → 1 位小数
        return String(format: "%.1f MB/s", Double(bytes) / 1_000_000)
    case 100_000_000..<1_000_000_000: // 100 ~ 999 MB/s → 整数
        return "\(bytes / 1_000_000) MB/s"
    default: // ≥ 1 GB/s → 1 位小数
        return String(format: "%.1f GB/s", Double(bytes) / 1_000_000_000)
    }
}

/// 格式化 CPU/GPU 使用率（如 "CPU 50%"），宽度固定 3 位数字
func formatCPUPercent(_ percent: Double) -> String {
    String(format: "%3d%%", Int(round(percent)))
}

/// 格式化内存用量，返回 (显示文本, 百分比文本)
func formatMemoryGB(_ usedGB: Double, percent: Double) -> (top: String, bottom: String) {
    let used = Int(round(usedGB))
    guard percent > 0 else { return ("MEM", "---") }
    let total = Int(round(usedGB / (percent / 100)))
    return ("MEM", "\(used)/\(total) GB")
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
