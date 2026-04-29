import Foundation

struct AppConstants {
    static let defaultValue = "--"

    struct Version {
        static var current: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        }
        static var build: String {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        }
        static var description: String {
            Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? ""
        }
        static var displayVersion: String {
            "v\(current)"
        }
    }

    struct AppInfo {
        static let name = "iMoni - AI Service Latency Monitor"
        static let description = """
        A lightweight macOS menu bar app for real-time monitoring of AI service network latency and bandwidth usage.
        © 2024 iMoni App
        """
        static let confirmButtonText = "OK"
    }
}

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

enum ConnectionStatus {
    case connected
    case disconnected
}

struct MonitorConstants {
    static let connectionTimeout: TimeInterval = 1.5

    static let defaultLatencyInterval: TimeInterval = 1.0
    static let defaultNetworkInterval: TimeInterval = 1.0

    static let availableIntervals: [TimeInterval] = [0.5, 1.0, 2.0, 5.0]
    static let defaultUserInterval: TimeInterval = 1.0

    static let minInterval: TimeInterval = 0.5
    static let maxInterval: TimeInterval = 60.0

    static let latencyQueueLabel = "com.imoni.latency"
    static let networkQueueLabel = "com.imoni.network"

    static let maxReasonableSpeed: Double = 1000.0
    static let activeInterfaceFlags: Int32 = IFF_UP
}
