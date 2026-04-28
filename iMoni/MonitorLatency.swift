import Foundation
import Network

protocol MonitorLatencyDelegate: AnyObject {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint)
}

class MonitorLatency: BaseMonitor {
    weak var delegate: MonitorLatencyDelegate?

    private var currentEndpoint: ServiceEndpoint?
    private var currentConnection: NWConnection?
    private var currentTimeoutWorkItem: DispatchWorkItem?

    override init(queueLabel: String, interval: TimeInterval) {
        super.init(queueLabel: queueLabel, interval: interval)
    }

    func startMonitoring(_ endpoint: ServiceEndpoint) {
        stopMonitoring()
        currentEndpoint = endpoint
        super.startMonitoring()
        queue.async { [weak self] in
            self?.performMonitoring()
        }
    }

    override func stopMonitoring() {
        super.stopMonitoring()
        cleanupCurrentConnection()
        currentEndpoint = nil
    }

    override func performMonitoring() {
        guard let endpoint = currentEndpoint else { return }
        guard currentConnection == nil else { return }
        pingEndpoint(endpoint)
    }

    override func cleanupResources() {
        cleanupCurrentConnection()
    }

    private func pingEndpoint(_ endpoint: ServiceEndpoint) {
        let startTime = Utilities.currentTimestamp()

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(endpoint.port)),
            using: .tcp
        )
        currentConnection = connection
        connection.start(queue: queue)

        currentTimeoutWorkItem?.cancel()
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.handleConnectionTimeout(for: endpoint, startTime: startTime)
        }
        currentTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.global().asyncAfter(deadline: .now() + MonitorConstants.connectionTimeout, execute: timeoutWorkItem)

        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(state, for: endpoint, startTime: startTime, timeoutWorkItem: timeoutWorkItem)
        }
    }

    private func handleConnectionStateChange(_ state: NWConnection.State, for endpoint: ServiceEndpoint, startTime: CFAbsoluteTime, timeoutWorkItem: DispatchWorkItem) {
        switch state {
        case .ready:
            timeoutWorkItem.cancel()
            let latency = Utilities.timeDifference(from: startTime)
            cleanupCurrentConnection()
            Utilities.safeMainQueueCallback { [weak self] in
                guard let self = self else { return }
                self.delegate?.monitor(self, didUpdateLatency: latency, for: endpoint)
            }

        case .failed:
            timeoutWorkItem.cancel()
            handleConnectionFailure(for: endpoint)

        case .cancelled:
            timeoutWorkItem.cancel()

        case .waiting, .preparing, .setup:
            break

        @unknown default:
            #if DEBUG
            Utilities.debugPrint("Unknown NWConnection state for \(endpoint.name): \(state)")
            #endif
        }
    }

    private func handleConnectionTimeout(for endpoint: ServiceEndpoint, startTime: CFAbsoluteTime) {
        cleanupCurrentConnection()
        handleConnectionFailure(for: endpoint)
    }

    private func handleConnectionFailure(for endpoint: ServiceEndpoint) {
        cleanupCurrentConnection()
        Utilities.safeMainQueueCallback { [weak self] in
            guard let self = self else { return }
            self.delegate?.monitor(self, didFailWithError: ConnectionStatus.disconnected, for: endpoint)
        }
    }

    private func cleanupCurrentConnection() {
        currentTimeoutWorkItem?.cancel()
        currentTimeoutWorkItem = nil
        currentConnection?.cancel()
        currentConnection = nil
    }
}
