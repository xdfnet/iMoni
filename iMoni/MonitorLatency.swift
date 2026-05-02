import Foundation
import Network

protocol MonitorLatencyDelegate: AnyObject {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint)
}

class MonitorLatency {
    weak var delegate: MonitorLatencyDelegate?

    private var timer: Timer?
    private var currentEndpoint: ServiceEndpoint?
    private var currentConnection: NWConnection?
    private var currentTimeoutWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: MonitorConstants.latencyQueueLabel, qos: .utility)
    private var interval: TimeInterval

    init(interval: TimeInterval = MonitorConstants.defaultInterval) {
        self.interval = interval
    }

    func startMonitoring(_ endpoint: ServiceEndpoint) {
        stopMonitoring()
        currentEndpoint = endpoint
        startTimer()
        queue.async { [weak self] in self?.ping() }
    }

    func stopMonitoring() {
        stopTimer()
        cleanupConnection()
        currentEndpoint = nil
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
            self?.queue.async { self?.ping() }
        }
        timer?.tolerance = min(interval * 0.1, 0.1)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func ping() {
        guard let endpoint = currentEndpoint, currentConnection == nil else { return }
        let startTime = CFAbsoluteTimeGetCurrent()

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(endpoint.port)),
            using: .tcp
        )
        currentConnection = connection
        connection.start(queue: queue)

        currentTimeoutWorkItem?.cancel()
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.handleTimeout(for: endpoint, startTime: startTime)
        }
        currentTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.global().asyncAfter(deadline: .now() + MonitorConstants.connectionTimeout, execute: timeoutWorkItem)

        connection.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state, for: endpoint, startTime: startTime, timeoutWorkItem: timeoutWorkItem)
        }
    }

    private func handleStateChange(_ state: NWConnection.State, for endpoint: ServiceEndpoint, startTime: CFAbsoluteTime, timeoutWorkItem: DispatchWorkItem) {
        switch state {
        case .ready:
            timeoutWorkItem.cancel()
            let latency = CFAbsoluteTimeGetCurrent() - startTime
            cleanupConnection()
            mainQueue { [weak self] in
                guard let self = self else { return }
                self.delegate?.monitor(self, didUpdateLatency: latency, for: endpoint)
            }
        case .failed:
            timeoutWorkItem.cancel()
            handleFailure(for: endpoint)
        case .cancelled:
            timeoutWorkItem.cancel()
        case .waiting, .preparing, .setup:
            break
        @unknown default:
            break
        }
    }

    private func handleTimeout(for endpoint: ServiceEndpoint, startTime: CFAbsoluteTime) {
        cleanupConnection()
        handleFailure(for: endpoint)
    }

    private func handleFailure(for endpoint: ServiceEndpoint) {
        cleanupConnection()
        mainQueue { [weak self] in
            guard let self = self else { return }
            self.delegate?.monitor(self, didFailWithError: .disconnected, for: endpoint)
        }
    }

    private func cleanupConnection() {
        currentTimeoutWorkItem?.cancel()
        currentTimeoutWorkItem = nil
        currentConnection?.cancel()
        currentConnection = nil
    }
}
