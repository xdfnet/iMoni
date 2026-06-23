import Foundation

protocol MonitorNetworkDelegate: AnyObject {
    func networkMonitor(_ monitor: MonitorNetwork, didUpdateSpeed uploadSpeed: Double, downloadSpeed: Double)
    func networkMonitorDidFail(_ monitor: MonitorNetwork)
}

class MonitorNetwork {
    weak var delegate: MonitorNetworkDelegate?

    private let timer = TimerHelper()
    private var isRunning = false
    private let queue = DispatchQueue(label: MonitorConstants.networkQueueLabel, qos: .utility)
    private var interval: TimeInterval
    private var lastBytesReceived: UInt64 = 0
    private var lastBytesSent: UInt64 = 0
    private var lastUpdateTime: CFAbsoluteTime = 0

    // 上次采样的链路速率（Mbits/s），用于动态计算毛刺阈值
    private var lastLinkRate: Double = 0

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        guard let initial = totalBytes() else {
            delegate?.networkMonitorDidFail(self)
            return
        }
        lastBytesReceived = initial.received
        lastBytesSent = initial.sent
        lastUpdateTime = CFAbsoluteTimeGetCurrent()
        self.interval = interval
        isRunning = true
        timer.start(queue: queue, interval: interval) { [weak self] in self?.update() }
    }

    func stopMonitoring() {
        isRunning = false
        timer.stop()
        lastBytesReceived = 0
        lastBytesSent = 0
        lastLinkRate = 0
        lastUpdateTime = 0
    }

    func cleanup() { stopMonitoring() }

    func updateInterval(_ newInterval: TimeInterval) {
        let wasActive = timer.isActive
        timer.stop()
        interval = newInterval
        if wasActive {
            timer.start(queue: queue, interval: interval) { [weak self] in self?.update() }
        }
    }

    // MARK: - Data

    private func update() {
        guard isRunning else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastUpdateTime
        guard elapsed > 0.01 else { return }

        guard let current = totalBytes() else {
            mainQueue { [weak self] in
                guard let self else { return }
                self.delegate?.networkMonitorDidFail(self)
            }
            return
        }

        var diffReceived: UInt64 = 0
        var diffSent: UInt64 = 0

        if current.received >= lastBytesReceived {
            diffReceived = current.received - lastBytesReceived
        } else {
            // 32-bit 计数器溢出（ifi_ibytes 是 u_int32_t，约 4GB 归零）
            diffReceived = current.received + (UInt64(UInt32.max) + 1) - lastBytesReceived
        }
        if current.sent >= lastBytesSent {
            diffSent = current.sent - lastBytesSent
        } else {
            diffSent = current.sent + (UInt64(UInt32.max) + 1) - lastBytesSent
        }

        lastBytesReceived = current.received
        lastBytesSent = current.sent

        // 毛刺阈值：基于链路速率 × 1.5 倍系数（覆盖突发）
        // lastLinkRate 单位是 Mbits/s，换算 bytes/s：* 1_000_000 / 8
        // 首次启动无链路速率时，用 1000 Mbps（千兆）作为安全默认值
        let linkRate = lastLinkRate > 0 ? lastLinkRate : 1000.0
        let intervalSec = max(self.interval, 0.5)
        let maxDelta = UInt64(linkRate * 1_000_000 / 8 * 1.5 * intervalSec)
        if diffReceived > maxDelta { diffReceived = 0 }
        if diffSent > maxDelta { diffSent = 0 }

        let speedDown = Double(diffReceived) / elapsed / (1000.0 * 1000.0)
        let speedUp = Double(diffSent) / elapsed / (1000.0 * 1000.0)

        lastUpdateTime = now

        mainQueue { [weak self] in
            guard let self else { return }
            self.delegate?.networkMonitor(self, didUpdateSpeed: speedUp, downloadSpeed: speedDown)
        }
    }

    private func totalBytes() -> (sent: UInt64, received: UInt64)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0
        var maxBaud: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = start
        while let cur = cursor {
            let flags = Int32(cur.pointee.ifa_flags)
            if (flags & IFF_LOOPBACK) == 0,
               let addr = cur.pointee.ifa_addr?.pointee,
               addr.sa_family == AF_LINK,
               let data = cur.pointee.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                totalSent += UInt64(stats.ifi_obytes)
                totalReceived += UInt64(stats.ifi_ibytes)
                let baud = UInt64(stats.ifi_baudrate)
                if baud > maxBaud { maxBaud = baud }
            }
            cursor = cur.pointee.ifa_next
        }

        if maxBaud > 0 {
            lastLinkRate = Double(maxBaud) / 1_000_000.0
        }

        return (totalSent, totalReceived)
    }
}
