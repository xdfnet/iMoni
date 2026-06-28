import Foundation
import Darwin
import Network
import OSLog

private let debugLog = OSLog(subsystem: "com.imoni", category: "stability")

// MARK: - Delegate

protocol MonitorStabilityDelegate: AnyObject {
    func stabilityMonitor(_ monitor: MonitorStability, didUpdateLatency latency: Double, lossRate: Double, jitter: Double)
    func stabilityMonitorDidFail(_ monitor: MonitorStability)
}

// MARK: - Monitor

/// 网络稳定性监控器，通过 HTTPS HEAD 请求测代理全链路延迟（同 OpenClash 测速方式）。
/// 保持长连接，只测 HEAD 请求往返时间，排除 TCP/TLS 建连开销。
class MonitorStability {
    weak var delegate: MonitorStabilityDelegate?
    private let queue = DispatchQueue(label: "com.imoni.stability", qos: .utility)
    private let timer = TimerHelper()
    private let connQueue = DispatchQueue(label: "com.imoni.stability.conn", qos: .utility)

    private let targetHost = "www.gstatic.com"
    private let targetPort: UInt16 = 443
    private let connectTimeout: TimeInterval = 5.0
    private let maxSamples = 20

    private var history: [Double] = []
    private var isRunning = false
    private var persistentConn: NWConnection?
    private var connReady = false

    deinit {
        stopMonitoring()
    }

    func startMonitoring(interval: TimeInterval = 1.0) {
        guard !isRunning else { return }
        isRunning = true
        history.removeAll()
        connect()
        timer.start(queue: queue, interval: interval) { [weak self] in
            self?.measure()
        }
    }

    func stopMonitoring() {
        isRunning = false
        timer.stop()
        disconnect()
    }

    // MARK: - Connection

    private func connect() {
        disconnect()
        connReady = false
        let host = NWEndpoint.Host(targetHost)
        let port = NWEndpoint.Port(integerLiteral: targetPort)
        let tlsOpts = NWProtocolTLS.Options()
        let params = NWParameters(tls: tlsOpts)
        let conn = NWConnection(host: host, port: port, using: params)

        conn.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            switch state {
            case .ready:
                self?.connReady = true
            case .failed(let err):
                self?.connReady = false
                os_log(.debug, log: debugLog, "连接断开: %@", err.localizedDescription)
                // 下次 measure 会自动重连
            case .cancelled:
                self?.connReady = false
            default:
                break
            }
        }
        conn.start(queue: connQueue)
        persistentConn = conn
    }

    private func disconnect() {
        persistentConn?.cancel()
        persistentConn = nil
        connReady = false
    }

    // MARK: - Measure

    /// 在长连接上发送 HEAD 请求，仅测往返时间
    private func measure() {
        // 连接挂了就重连，本次不计入有效数据
        guard let conn = persistentConn, connReady else {
            connect()
            recordResult(success: false, elapsedMs: -1)
            return
        }

        let start = Date()
        let sem = DispatchSemaphore(value: 0)
        var success = false

        let request = "HEAD /generate_204 HTTP/1.1\r\nHost: \(targetHost)\r\nConnection: keep-alive\r\nUser-Agent: iMoni\r\n\r\n"
        conn.send(content: request.data(using: .utf8), completion: .idempotent)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
            if data != nil {
                success = true
            } else if let error = error {
                os_log(.debug, log: debugLog, "receive 错误: %@", error.localizedDescription)
            }
            sem.signal()
        }

        _ = sem.wait(timeout: .now() + connectTimeout)
        let elapsedMs = Date().timeIntervalSince(start) * 1000

        // 如果连接在请求过程中挂了，重建
        if !success {
            disconnect()
        }

        recordResult(success: success, elapsedMs: elapsedMs)
    }

    private func recordResult(success: Bool, elapsedMs: Double) {
        history.append(success ? elapsedMs : -1)
        if history.count > maxSamples {
            history.removeFirst()
        }

        let valid = history.filter { $0 >= 0 }
        let timeoutCount = history.filter { $0 < 0 }.count
        let lossRate = history.count > 0 ? Double(timeoutCount) / Double(history.count) : 0

        let jitter: Double
        if valid.isEmpty {
            jitter = 0
        } else {
            let avg = valid.reduce(0, +) / Double(valid.count)
            jitter = valid.map { abs($0 - avg) }.reduce(0, +) / Double(valid.count)
        }

        let currentLatency = success ? elapsedMs : -1

        os_log(.debug, log: debugLog, "Top: %.0fms  ✕%.1f%%  ±%.1fms (samples: %d/%d)",
               currentLatency, lossRate * 100, jitter,
               valid.count, history.count)

        mainQueue { [weak self] in
            guard let self else { return }
            self.delegate?.stabilityMonitor(self, didUpdateLatency: currentLatency, lossRate: lossRate, jitter: jitter)
        }
    }
}
