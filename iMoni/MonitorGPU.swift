import Foundation
import IOKit

// MARK: - GPU Monitor Delegate

protocol MonitorGPUDelegate: AnyObject {
    func gpuMonitor(_ monitor: MonitorGPU, didUpdateGPUUsage percent: Double)
    func gpuMonitorDidFail(_ monitor: MonitorGPU)
}

// MARK: - GPU Monitor

class MonitorGPU {
    weak var delegate: MonitorGPUDelegate?

    private let timer = TimerHelper()
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.imoni.gpu", qos: .utility)
    private var interval: TimeInterval

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
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
        guard let usage = getGPUUsage() else {
            mainQueue { [weak self] in
                guard let self else { return }
                self.delegate?.gpuMonitorDidFail(self)
            }
            return
        }

        mainQueue { [weak self] in
            guard let self else { return }
            self.delegate?.gpuMonitor(self, didUpdateGPUUsage: usage)
        }
    }

    private func getGPUUsage() -> Double? {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var totalUsage: Double = 0
        var count = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = properties?.takeRetainedValue() as? [String: Any],
               let stats = props["PerformanceStatistics"] as? [String: Any] {

                if let usage = stats["Device Utilization %"] as? Double {
                    totalUsage += usage; count += 1
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return count > 0 ? totalUsage / Double(count) : nil
    }
}
