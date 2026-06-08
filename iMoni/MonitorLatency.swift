import Foundation

protocol MonitorLatencyDelegate: AnyObject {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint)
}

class MonitorLatency {
    weak var delegate: MonitorLatencyDelegate?

    private var timer: Timer?
    private var currentEndpoint: ServiceEndpoint?
    private let queue = DispatchQueue(label: MonitorConstants.latencyQueueLabel, qos: .utility)
    private var interval: TimeInterval
    private var isPinging = false

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(_ endpoint: ServiceEndpoint) {
        stopMonitoring()
        currentEndpoint = endpoint
        startTimer()
        queue.async { [weak self] in self?.ping() }
    }

    func stopMonitoring() {
        stopTimer()
        currentEndpoint = nil
    }

    func cleanup() {
        stopMonitoring()
    }

    func updateInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        if timer != nil { startTimer() }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.queue.async { self?.ping() }
        }
        timer?.tolerance = min(interval * 0.1, 0.1)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func ping() {
        guard let endpoint = currentEndpoint, !isPinging else { return }
        isPinging = true
        let start = CFAbsoluteTimeGetCurrent()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = ["-c", "1", "-t", "1", endpoint.host]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.terminationHandler = { [weak self] process in
            guard let self else { return }
            defer { self.isPinging = false }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            if process.terminationStatus == 0 {
                // 解析 ping 输出: "time=12.345 ms"
                if let timeStr = self.parsePingTime(from: output) {
                    let latency = timeStr / 1000.0 // ms → seconds
                    mainQueue {
                        self.delegate?.monitor(self, didUpdateLatency: latency, for: endpoint)
                    }
                } else {
                    // 有输出但没解析出时间，用总耗时作为延迟
                    mainQueue {
                        self.delegate?.monitor(self, didUpdateLatency: min(elapsed, 2.0), for: endpoint)
                    }
                }
            } else {
                mainQueue {
                    self.delegate?.monitor(self, didFailWithError: .disconnected, for: endpoint)
                }
            }
        }

        do {
            try task.run()
        } catch {
            isPinging = false
            mainQueue {
                self.delegate?.monitor(self, didFailWithError: .disconnected, for: endpoint)
            }
        }
    }

    /// 从 ping 输出中提取 "time=XX.XXX" 或 "time<XX.XXX" 毫秒值
    private func parsePingTime(from output: String) -> Double? {
        // macOS ping: "time=12.345 ms" 或 "time<1.0 ms"
        let patterns = [
            try? NSRegularExpression(pattern: "time[=<](\\d+(?:\\.\\d+)?)\\s*ms"),
        ]
        for pattern in patterns.compactMap({ $0 }) {
            if let match = pattern.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output) {
                return Double(output[range])
            }
        }
        return nil
    }
}
