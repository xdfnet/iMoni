import Foundation

protocol BaseMonitorProtocol: AnyObject {
    var isMonitoring: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    func cleanup()
}

class BaseMonitor: BaseMonitorProtocol {
    private(set) var isMonitoring: Bool = false
    internal var monitorTimer: Timer?
    internal let queue: DispatchQueue
    internal var monitoringInterval: TimeInterval
    private let monitoringLock = NSLock()

    init(queueLabel: String, interval: TimeInterval) {
        self.queue = DispatchQueue(label: queueLabel, qos: .utility)
        self.monitoringInterval = interval
    }

    deinit {
        cleanup()
    }

    func startMonitoring() {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        guard !isMonitoring else { return }
        isMonitoring = true
        startTimer()
    }

    func stopMonitoring() {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        guard isMonitoring else { return }
        stopTimer()
        isMonitoring = false
    }

    func cleanup() {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        stopTimer()
        isMonitoring = false
        cleanupResources()
    }

    func updateInterval(_ newInterval: TimeInterval) {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }

        let validatedInterval = max(MonitorConstants.minInterval,
                                  min(newInterval, MonitorConstants.maxInterval))
        monitoringInterval = validatedInterval

        if isMonitoring {
            restartTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.performMonitoring()
            }
        }
        monitorTimer?.tolerance = min(monitoringInterval * 0.1, 0.1)
    }

    private func stopTimer() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func restartTimer() {
        if isMonitoring {
            startTimer()
        }
    }

    func performMonitoring() {
        fatalError("subclasses must override performMonitoring()")
    }

    func cleanupResources() {
        // subclass hook
    }
}
