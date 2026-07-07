import Foundation

// MARK: - CPU Monitor Delegate

protocol MonitorCPUDelegate: AnyObject {
    func cpuMonitor(_ monitor: MonitorCPU, didUpdateCPUUsage percent: Double)
    func cpuMonitorDidFail(_ monitor: MonitorCPU)
}

// MARK: - CPU Monitor

class MonitorCPU {
    weak var delegate: MonitorCPUDelegate?

    private let timer = TimerHelper()
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.imoni.cpu", qos: .utility)
    private var interval: TimeInterval

    private var prevCpuInfo: UnsafeMutablePointer<integer_t>?
    private var prevNumCpuInfo: mach_msg_type_number_t = 0

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    deinit { freePrevCpuInfo() }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
        isRunning = true
        freePrevCpuInfo()
        prevCpuInfo = nil
        prevNumCpuInfo = 0
        timer.start(queue: queue, interval: interval) { [weak self] in self?.update() }
        queue.async { [weak self] in self?.update() }
    }

    func stopMonitoring() {
        isRunning = false
        timer.stop()
        freePrevCpuInfo()
        prevCpuInfo = nil
        prevNumCpuInfo = 0
    }

    func cleanup() { stopMonitoring() }

    // MARK: - Data

    private func update() {
        guard isRunning else { return }

        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t? = nil
        var numCpuInfo: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCpuInfo
        )
        guard kr == KERN_SUCCESS, let current = cpuInfo else {
            mainQueue { [weak self] in
                guard let self else { return }
                self.delegate?.cpuMonitorDidFail(self)
            }
            return
        }

        if let prev = prevCpuInfo, prevNumCpuInfo > 0 {
            var totalInUse: Int32 = 0
            var total: Int32 = 0
            let cpuCount = Int(numCPUs)
            let step = Int(CPU_STATE_MAX)

            for i in 0 ..< cpuCount {
                let base = i * step
                let user   = current[base + Int(CPU_STATE_USER)]   - prev[base + Int(CPU_STATE_USER)]
                let system = current[base + Int(CPU_STATE_SYSTEM)] - prev[base + Int(CPU_STATE_SYSTEM)]
                let idle   = current[base + Int(CPU_STATE_IDLE)]   - prev[base + Int(CPU_STATE_IDLE)]
                let nice   = current[base + Int(CPU_STATE_NICE)]   - prev[base + Int(CPU_STATE_NICE)]

                let inUse = user + system + nice
                let totalTicks = inUse + idle
                totalInUse += inUse
                total += totalTicks
            }

            if total > 0 {
                let percent = Double(totalInUse) / Double(total) * 100.0
                mainQueue { [weak self] in
                    guard let self else { return }
                    self.delegate?.cpuMonitor(self, didUpdateCPUUsage: percent)
                }
            }
        }

        freePrevCpuInfo()
        prevCpuInfo = current
        prevNumCpuInfo = numCpuInfo
    }

    private func freePrevCpuInfo() {
        guard let p = prevCpuInfo else { return }
        let size = vm_size_t(prevNumCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: p)), size)
    }
}
