import Foundation

// MARK: - Memory Monitor Delegate

protocol MonitorMemoryDelegate: AnyObject {
    func memoryMonitor(_ monitor: MonitorMemory, didUpdateMemoryUsed usedGB: Double, percent: Double)
    func memoryMonitorDidFail(_ monitor: MonitorMemory)
}

// MARK: - Memory Monitor

class MonitorMemory {
    weak var delegate: MonitorMemoryDelegate?

    private let timer = TimerHelper()
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.imoni.memory", qos: .utility)
    private var interval: TimeInterval
    private var totalMemory: UInt64 = 0

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
        self.totalMemory = getTotalMemory()
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
        if totalMemory == 0 { totalMemory = getTotalMemory() }
        isRunning = true
        timer.start(queue: queue, interval: interval) { [weak self] in self?.update() }
        queue.async { [weak self] in self?.update() }
    }

    func stopMonitoring() {
        isRunning = false
        timer.stop()
    }

    func cleanup() { stopMonitoring() }

    // MARK: - Data

    private func update() {
        guard isRunning else { return }
        guard let (usedBytes, _) = getMemoryUsage() else {
            mainQueue { [weak self] in
                guard let self else { return }
                self.delegate?.memoryMonitorDidFail(self)
            }
            return
        }

        let usedGB = Double(usedBytes) / (1024.0 * 1024.0 * 1024.0)
        let percent = totalMemory > 0 ? Double(usedBytes) / Double(totalMemory) * 100.0 : 0

        mainQueue { [weak self] in
            guard let self else { return }
            self.delegate?.memoryMonitor(self, didUpdateMemoryUsed: usedGB, percent: percent)
        }
    }

    private func getTotalMemory() -> UInt64 {
        var info = host_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? info.max_mem : 0
    }

    private func getMemoryUsage() -> (used: UInt64, free: UInt64)? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let page = UInt64(vm_page_size)
        let active     = UInt64(stats.active_count) * page
        let inactive   = UInt64(stats.inactive_count) * page
        let speculative = UInt64(stats.speculative_count) * page
        let wired      = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let purgeable  = UInt64(stats.purgeable_count) * page
        let external   = UInt64(stats.external_page_count) * page

        let used = active + inactive + speculative + wired + compressed - purgeable - external
        return (used, totalMemory - used)
    }
}
