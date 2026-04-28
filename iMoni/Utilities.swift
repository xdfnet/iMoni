import Foundation

struct Utilities {
    // MARK: - Formatting
    static func formatLatency(_ latency: TimeInterval) -> String {
        let latencyMs = latency * 1000
        return String(format: "%.0fms", latencyMs)
    }

    static func formatSpeed(_ speed: Double) -> String {
        String(format: "%.2fMB/s", speed)
    }

    static func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 1.0 {
            return "\(interval)s"
        } else {
            return "\(Int(interval))s"
        }
    }

    // MARK: - Time
    static func currentTimestamp() -> CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }

    static func timeDifference(from startTime: CFAbsoluteTime) -> TimeInterval {
        currentTimestamp() - startTime
    }

    // MARK: - Thread Safety
    static func safeMainQueueCallback(_ callback: @escaping () -> Void) {
        if Thread.isMainThread {
            callback()
        } else {
            DispatchQueue.main.async(execute: callback)
        }
    }

    static func safeMainQueueCallback<T: AnyObject>(_ object: T, _ callback: @escaping (T) -> Void) {
        safeMainQueueCallback { [weak object] in
            guard let object = object else { return }
            callback(object)
        }
    }

    // MARK: - Numeric
    static func safeInt(_ value: Any?, defaultValue: Int = 0) -> Int {
        if let intValue = value as? Int {
            return intValue
        } else if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue
        } else if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        return defaultValue
    }

    static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        Swift.max(min, Swift.min(value, max))
    }

    // MARK: - Validation
    static func validateServiceEndpoint(_ endpoint: ServiceEndpoint) -> Bool {
        !endpoint.name.isEmpty && !endpoint.host.isEmpty && endpoint.port > 0 && endpoint.port <= 65535
    }

    // MARK: - Performance
    static func measureExecutionTime<T>(_ operation: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = currentTimestamp()
        let result = try operation()
        let duration = currentTimestamp() - startTime
        return (result, duration)
    }

    // MARK: - Debug
    static func debugPrint(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("[\(fileName):\(line)] \(function): \(message)")
        #endif
    }

    static func printPerformanceStats(_ name: String, duration: TimeInterval) {
        #if DEBUG
        print("[\(name)] Duration: \(String(format: "%.3f", duration))s")
        #endif
    }
}
