import Foundation

protocol MonitorNetworkDelegate: AnyObject {
    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double)
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus)
}

class MonitorNetwork {
    weak var delegate: MonitorNetworkDelegate?

    private var timer: Timer?
    private var isRunning = false
    private let queue = DispatchQueue(label: MonitorConstants.networkQueueLabel, qos: .utility)
    private var interval: TimeInterval
    private var lastBytesReceived: UInt64 = 0
    private var lastUpdateTime: CFAbsoluteTime = 0

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        guard let initial = totalRxBytes() else {
            delegate?.networkStats(self, didFailWithError: .disconnected)
            return
        }
        lastBytesReceived = initial
        lastUpdateTime = CFAbsoluteTimeGetCurrent()
        self.interval = interval
        isRunning = true
        startTimer()
    }

    func stopMonitoring() {
        isRunning = false
        stopTimer()
        lastBytesReceived = 0
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

        guard let currentBytes = totalRxBytes() else {
            mainQueue { [weak self] in
                self?.delegate?.networkStats(self!, didFailWithError: .disconnected)
            }
            return
        }

        guard currentBytes >= lastBytesReceived else {
            lastBytesReceived = currentBytes
            lastUpdateTime = now
            return
        }

        let diff = currentBytes - lastBytesReceived
        let speed = Double(diff) / elapsed / (1000.0 * 1000.0)

        guard speed <= MonitorConstants.maxReasonableSpeed else {
            lastBytesReceived = currentBytes
            lastUpdateTime = now
            return
        }

        lastBytesReceived = currentBytes
        lastUpdateTime = now

        mainQueue { [weak self] in
            self?.delegate?.networkStats(self!, didUpdateDownloadSpeed: speed)
        }
    }

    /// Total bytes received across all non-loopback interfaces via getifaddrs + AF_LINK.
    private func totalRxBytes() -> UInt64? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var total: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = start
        while let cur = cursor {
            let flags = Int32(cur.pointee.ifa_flags)
            if (flags & IFF_LOOPBACK) == 0,
               let addr = cur.pointee.ifa_addr?.pointee,
               addr.sa_family == AF_LINK,
               let data = cur.pointee.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                total += UInt64(stats.ifi_ibytes)
            }
            cursor = cur.pointee.ifa_next
        }
        return total
    }
}
