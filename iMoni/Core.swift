import Foundation
import AppKit

// MARK: - Service Endpoint

struct ServiceEndpoint {
    let name: String
    let host: String
    let port: Int

    init(name: String, host: String, port: Int = 443) {
        self.name = name
        self.host = host
        self.port = port
    }
}

// MARK: - AI Services

let services: [ServiceEndpoint] = [
    ServiceEndpoint(name: "OpenAI", host: "api.openai.com"),
    ServiceEndpoint(name: "Claude", host: "api.anthropic.com"),
    ServiceEndpoint(name: "Gemini", host: "generativelanguage.googleapis.com"),
    ServiceEndpoint(name: "DeepSeek", host: "api.deepseek.com"),
    ServiceEndpoint(name: "GLM", host: "open.bigmodel.cn"),
    ServiceEndpoint(name: "Qwen", host: "dashscope.aliyuncs.com"),
    ServiceEndpoint(name: "Kimi", host: "api.moonshot.cn"),
]

// MARK: - Enums

enum ConnectionStatus {
    case connected
    case disconnected
}

enum DisplayMode: String, CaseIterable {
    case serviceLatency = "Service"
    case networkSpeed = "Network"
}

// MARK: - Constants

enum MonitorConstants {
    static let connectionTimeout: TimeInterval = 0.5
    static let defaultInterval: TimeInterval = 1.0
    static let availableIntervals: [TimeInterval] = [0.5, 1.0, 2.0, 5.0]
    static let maxReasonableSpeed: Double = 1000.0
    static let latencyQueueLabel = "com.imoni.latency"
    static let networkQueueLabel = "com.imoni.network"
}

// MARK: - User Defaults

extension UserDefaults {
    var displayMode: DisplayMode {
        get {
            guard let raw = string(forKey: "displayMode"),
                  let mode = DisplayMode(rawValue: raw) else { return .serviceLatency }
            return mode
        }
        set { set(newValue.rawValue, forKey: "displayMode") }
    }

    var monitoringInterval: TimeInterval {
        get {
            let val = double(forKey: "monitoringInterval")
            if val > 0 { return max(0.5, min(val, 60.0)) }
            return MonitorConstants.defaultInterval
        }
        set { set(max(0.5, min(newValue, 60.0)), forKey: "monitoringInterval") }
    }

    var lastServiceName: String? {
        get { string(forKey: "lastServiceName") }
        set { set(newValue, forKey: "lastServiceName") }
    }
}

// MARK: - Formatting & Dispatch

func formatLatency(_ latency: TimeInterval) -> String {
    String(format: "%.0fms", latency * 1000)
}

func formatSpeed(_ speed: Double) -> String {
    let units = ["B/s", "KB/s", "MB/s", "GB/s"]
    var value = speed * 1000 * 1000  // MB/s → B/s
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
