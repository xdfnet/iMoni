import Foundation
import Network

protocol MonitorLatencyDelegate: AnyObject {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint)
}

class MonitorLatency {
    weak var delegate: MonitorLatencyDelegate?

    private let timer = TimerHelper()
    private var currentEndpoint: ServiceEndpoint?
    private var currentConnection: NWConnection?
    private var currentTimeoutWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: MonitorConstants.latencyQueueLabel, qos: .utility)
    private var interval: TimeInterval
    private var isPinging = false

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(_ endpoint: ServiceEndpoint) {
        stopMonitoring()
        currentEndpoint = endpoint
        timer.start(queue: queue, interval: interval, leeway: 50) { [weak self] in self?.ping() }
        queue.async { [weak self] in self?.ping() }
    }

    func stopMonitoring() {
        timer.stop()
        cleanupConnection()
        currentEndpoint = nil
        isPinging = false
    }

    func cleanup() { stopMonitoring() }

    func updateInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        if timer.isActive {
            timer.start(queue: queue, interval: interval, leeway: 50) { [weak self] in self?.ping() }
        }
    }

    // MARK: - Ping

    private func ping() {
        guard let endpoint = currentEndpoint, !isPinging else { return }
        isPinging = true
        let startTime = CFAbsoluteTimeGetCurrent()

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(endpoint.port)),
            using: .tcp
        )
        currentConnection = connection
        connection.start(queue: queue)

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.cleanupConnection()
            self.isPinging = false
            mainQueue {
                self.delegate?.monitor(self, didFailWithError: .disconnected, for: endpoint)
            }
        }
        currentTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.global().asyncAfter(deadline: .now() + MonitorConstants.connectionTimeout, execute: timeoutWorkItem)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                timeoutWorkItem.cancel()
                let latency = CFAbsoluteTimeGetCurrent() - startTime
                self.cleanupConnection()
                self.isPinging = false
                mainQueue {
                    self.delegate?.monitor(self, didUpdateLatency: latency, for: endpoint)
                }
            case .failed:
                timeoutWorkItem.cancel()
                self.cleanupConnection()
                self.isPinging = false
                mainQueue {
                    self.delegate?.monitor(self, didFailWithError: .disconnected, for: endpoint)
                }
            case .cancelled:
                timeoutWorkItem.cancel()
            case .waiting, .preparing, .setup:
                break
            @unknown default:
                break
            }
        }
    }

    private func cleanupConnection() {
        currentTimeoutWorkItem?.cancel()
        currentTimeoutWorkItem = nil
        currentConnection?.cancel()
        currentConnection = nil
    }
}
