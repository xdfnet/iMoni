import Foundation

// MARK: - Memory Monitor Delegate

protocol MonitorMemoryDelegate: AnyObject {
    func memoryMonitor(_ monitor: MonitorMemory, didUpdateMemoryUsed usedGB: Double, percent: Double)
    func memoryMonitorDidFail(_ monitor: MonitorMemory)
}

// MARK: - Memory Monitor

class MonitorMemory {
    weak var delegate: MonitorMemoryDelegate?

    private var timer: Timer?
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.imoni.memory", qos: .utility)
    private var interval: TimeInterval

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
        isRunning = true
        startTimer()
        queue.async { [weak self] in self?.update() }
    }

    func stopMonitoring() {
        isRunning = false
        stopTimer()
    }

    func cleanup() {
        stopMonitoring()
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
        guard let (usedGB, percent) = getMemoryUsage() else {
            mainQueue { [weak self] in
                guard let self else { return }
                self.delegate?.memoryMonitorDidFail(self)
            }
            return
        }

        mainQueue { [weak self] in
            guard let self else { return }
            self.delegate?.memoryMonitor(self, didUpdateMemoryUsed: usedGB, percent: percent)
        }
    }

    /// 获取已使用的物理内存（GB）和百分比
    private func getMemoryUsage() -> (usedGB: Double, percent: Double)? {
        let host = mach_host_self()

        var info = vm_statistics_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)

        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_VM_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let pageSize = Int(getpagesize())

        // total physical memory (bytes)
        let total = ProcessInfo.processInfo.physicalMemory

        // used = total - (free + inactive)
        let freePages = Int(info.free_count + info.inactive_count)
        let freeBytes = UInt64(freePages * pageSize)

        guard total > freeBytes else { return nil }

        let usedBytes = total - freeBytes
        let usedGB = Double(usedBytes) / (1000.0 * 1000.0 * 1000.0)
        let percent = Double(usedBytes) / Double(total) * 100.0

        return (usedGB, percent)
    }
}
