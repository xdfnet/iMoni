import Foundation

// MARK: - CPU Monitor Delegate

protocol MonitorCPUDelegate: AnyObject {
    func cpuMonitor(_ monitor: MonitorCPU, didUpdateCPUUsage percent: Double)
    func cpuMonitorDidFail(_ monitor: MonitorCPU)
}

// MARK: - CPU Monitor

class MonitorCPU {
    weak var delegate: MonitorCPUDelegate?

    private var timer: Timer?
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.imoni.cpu", qos: .utility)
    private var interval: TimeInterval
    private var previousLoad: host_cpu_load_info_data_t?
    private var previousTime: CFAbsoluteTime?

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
        isRunning = true
        previousLoad = nil
        previousTime = nil
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
        let current = getCPULoad()
        let now = CFAbsoluteTimeGetCurrent()

        if let prev = previousLoad, let prevTime = previousTime, now - prevTime > 0.01 {
            let userDelta = Double(current.cpu_ticks.0) - Double(prev.cpu_ticks.0)
            let systemDelta = Double(current.cpu_ticks.1) - Double(prev.cpu_ticks.1)
            let idleDelta = Double(current.cpu_ticks.2) - Double(prev.cpu_ticks.2)
            let niceDelta = Double(current.cpu_ticks.3) - Double(prev.cpu_ticks.3)

            let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
            if totalDelta > 0 {
                let usedDelta = userDelta + systemDelta + niceDelta
                let percent = usedDelta / totalDelta * 100.0

                mainQueue { [weak self] in
                    guard let self else { return }
                    self.delegate?.cpuMonitor(self, didUpdateCPUUsage: percent)
                }
            }
        } else {
            // First sample — just store it, no data to report yet
        }

        previousLoad = current
        previousTime = now
    }

    private func getCPULoad() -> host_cpu_load_info_data_t {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        return info
    }
}
