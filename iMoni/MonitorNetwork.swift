import Foundation

protocol MonitorNetworkDelegate: AnyObject {
    func networkStats(_ stats: MonitorNetwork, didUpdateSpeed uploadSpeed: Double, downloadSpeed: Double)
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus)
}

class MonitorNetwork {
    weak var delegate: MonitorNetworkDelegate?

    private var timer: Timer?
    private var isRunning = false
    private let queue = DispatchQueue(label: MonitorConstants.networkQueueLabel, qos: .utility)
    private var interval: TimeInterval
    private var lastBytesReceived: UInt64 = 0
    private var lastBytesSent: UInt64 = 0
    private var lastUpdateTime: CFAbsoluteTime = 0

    /// 累计总流量（从开始监控起）
    private var totalDownloadBytes: UInt64 = 0
    private var totalUploadBytes: UInt64 = 0

    /// 主接口链路速率 (Mbps)，用于动态毛刺阈值
    private var lastTransmitRate: Double = 0

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        guard let initial = totalBytes() else {
            delegate?.networkStats(self, didFailWithError: .disconnected)
            return
        }
        lastBytesReceived = initial.1
        lastBytesSent = initial.0
        totalDownloadBytes = 0
        totalUploadBytes = 0
        lastUpdateTime = CFAbsoluteTimeGetCurrent()
        self.interval = interval
        isRunning = true
        startTimer()
    }

    func stopMonitoring() {
        isRunning = false
        stopTimer()
        lastBytesReceived = 0
        lastBytesSent = 0
        totalDownloadBytes = 0
        totalUploadBytes = 0
        lastUpdateTime = 0
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
            self?.queue.async { self?.update() }
        }
        timer?.tolerance = min(interval * 0.1, 0.1)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard isRunning else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastUpdateTime
        guard elapsed > 0.01 else { return }

        guard let current = totalBytes() else {
            mainQueue { [weak self] in
                guard let self else { return }
                self.delegate?.networkStats(self, didFailWithError: .disconnected)
            }
            return
        }

        // 按字节计算差值（不经过 MB/s 转换，避免精度损失）
        var diffReceived: UInt64 = 0
        var diffSent: UInt64 = 0

        if current.1 >= lastBytesReceived {
            diffReceived = current.1 - lastBytesReceived
        }
        if current.0 >= lastBytesSent {
            diffSent = current.0 - lastBytesSent
        }

        lastBytesReceived = current.1
        lastBytesSent = current.0

        // 动态毛刺阈值：链路速率 × 1.5 倍容差（按间隔换算为字节）
        let maxDelta: UInt64 = {
            let intervalSec = max(self.interval, 0.5)
            if lastTransmitRate > 0 {
                // rate(Mbps) → bits/s → bytes/s → ×1.5 容差 → ×interval
                return UInt64(lastTransmitRate * 1_000_000 / 8 * 1.5 * intervalSec)
            }
            return UInt64(2_000_000_000 * intervalSec) // 16 Gbps fallback
        }()
        if diffReceived > maxDelta { diffReceived = 0 }
        if diffSent > maxDelta { diffSent = 0 }

        // 累计总流量
        totalDownloadBytes += diffReceived
        totalUploadBytes += diffSent

        // 转为 MB/s 供显示
        let speedDown = Double(diffReceived) / elapsed / (1000.0 * 1000.0)
        let speedUp = Double(diffSent) / elapsed / (1000.0 * 1000.0)

        lastUpdateTime = now

        mainQueue { [weak self] in
            guard let self else { return }
            self.delegate?.networkStats(self, didUpdateSpeed: speedUp, downloadSpeed: speedDown)
        }
    }

    /// 遍历非 loopback 接口，累加上下行总字节数，并捕获主接口链路速率
    private func totalBytes() -> (UInt64, UInt64)? {
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
                if baud > maxBaud {
                    maxBaud = baud
                }
            }
            cursor = cur.pointee.ifa_next
        }

        // 缓存最高链路速率（bps → Mbps）
        if maxBaud > 0 {
            lastTransmitRate = Double(maxBaud) / 1_000_000.0
        }

        return (totalSent, totalReceived)
    }
}
