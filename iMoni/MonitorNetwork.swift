import Foundation
import Darwin

protocol MonitorNetworkDelegate: AnyObject {
    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double, uploadSpeed: Double)
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus)
}

class MonitorNetwork: BaseMonitor {
    weak var delegate: MonitorNetworkDelegate?

    private var lastBytesReceived: UInt64 = 0
    private var lastBytesSent: UInt64 = 0
    private var lastUpdateTime: CFAbsoluteTime = 0
    private let statsLock = NSLock()

    override init(queueLabel: String, interval: TimeInterval) {
        super.init(queueLabel: queueLabel, interval: interval)
    }

    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultNetworkInterval) {
        do {
            let (totalReceived, totalSent) = try getTotalNetworkBytes()
            statsLock.lock()
            lastBytesReceived = totalReceived
            lastBytesSent = totalSent
            lastUpdateTime = Utilities.currentTimestamp()
            statsLock.unlock()
        } catch {
            delegate?.networkStats(self, didFailWithError: ConnectionStatus.disconnected)
            return
        }
        updateInterval(interval)
        super.startMonitoring()
    }

    override func stopMonitoring() {
        super.stopMonitoring()
        statsLock.lock()
        lastBytesReceived = 0
        lastBytesSent = 0
        lastUpdateTime = 0
        statsLock.unlock()
    }

    override func performMonitoring() {
        updateNetworkSpeeds()
    }

    override func cleanupResources() {}

    private func updateNetworkSpeeds() {
        let currentTime = Utilities.currentTimestamp()

        statsLock.lock()
        let lastTime = lastUpdateTime
        let lastReceived = lastBytesReceived
        let lastSent = lastBytesSent
        statsLock.unlock()

        let timeElapsed = currentTime - lastTime
        guard timeElapsed > 0 else { return }

        do {
            let (currentReceived, currentSent) = try getTotalNetworkBytes()

            guard currentReceived >= lastReceived, currentSent >= lastSent else {
                #if DEBUG
                Utilities.debugPrint("Network interface reset detected, reinitializing stats")
                #endif
                resetNetworkStats()
                return
            }

            let receivedDiff = currentReceived - lastReceived
            let sentDiff = currentSent - lastSent

            let bytesPerMB: Double = 1000.0 * 1000.0
            let downloadSpeedMBps = Double(receivedDiff) / timeElapsed / bytesPerMB
            let uploadSpeedMBps = Double(sentDiff) / timeElapsed / bytesPerMB

            guard downloadSpeedMBps >= 0 && downloadSpeedMBps <= MonitorConstants.maxReasonableSpeed,
                  uploadSpeedMBps >= 0 && uploadSpeedMBps <= MonitorConstants.maxReasonableSpeed else {
                #if DEBUG
                Utilities.debugPrint("Unreasonable speed detected: \(Utilities.formatSpeed(downloadSpeedMBps))")
                #endif
                resetNetworkStats()
                return
            }

            statsLock.lock()
            lastBytesReceived = currentReceived
            lastBytesSent = currentSent
            lastUpdateTime = currentTime
            statsLock.unlock()

            Utilities.safeMainQueueCallback { [weak self] in
                guard let self = self else { return }
                self.delegate?.networkStats(self, didUpdateDownloadSpeed: downloadSpeedMBps, uploadSpeed: uploadSpeedMBps)
            }
        } catch {
            Utilities.safeMainQueueCallback { [weak self] in
                guard let self = self else { return }
                self.delegate?.networkStats(self, didFailWithError: ConnectionStatus.disconnected)
            }
        }
    }

    private func resetNetworkStats() {
        do {
            let (totalReceived, totalSent) = try getTotalNetworkBytes()
            statsLock.lock()
            lastBytesReceived = totalReceived
            lastBytesSent = totalSent
            lastUpdateTime = Utilities.currentTimestamp()
            statsLock.unlock()
        } catch {
            #if DEBUG
            Utilities.debugPrint("Network error during reset: \(error.localizedDescription)")
            #endif
        }
    }

    private func getTotalNetworkBytes() throws -> (received: UInt64, sent: UInt64) {
        var totalReceivedBytes: UInt64 = 0
        var totalSentBytes: UInt64 = 0

        let mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        let routeMessagePrefixSize = MemoryLayout<UInt16>.size + MemoryLayout<UInt8>.size * 2
        let if2mSize = MemoryLayout<if_msghdr2>.size
        let maxMessageSize = 65536

        var len: size_t = 0
        let sysctlResult = mib.withUnsafeBufferPointer { mibBuffer in
            sysctl(UnsafeMutablePointer<Int32>(mutating: mibBuffer.baseAddress),
                   UInt32(mib.count), nil, &len, nil, 0)
        }
        guard sysctlResult >= 0, len > 0 else { throw NetworkError.sysctlFailed }

        var buffer = [CChar](repeating: 0, count: len)
        let sysctlResult2 = mib.withUnsafeBufferPointer { mibBuffer in
            sysctl(UnsafeMutablePointer<Int32>(mutating: mibBuffer.baseAddress),
                   UInt32(mib.count), &buffer, &len, nil, 0)
        }
        guard sysctlResult2 >= 0 else { throw NetworkError.sysctlFailed }

        buffer.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            var offset = 0
            while offset < len {
                guard offset + routeMessagePrefixSize <= len else { break }

                let baseAddr = rawPtr.baseAddress!.advanced(by: offset)
                let msgLen = Int(baseAddr.load(as: UInt16.self))
                let msgType = baseAddr.load(fromByteOffset: 3, as: UInt8.self)

                guard msgLen >= routeMessagePrefixSize, msgLen <= maxMessageSize, offset + msgLen <= len else {
                    break
                }

                if msgType == UInt8(RTM_IFINFO2) {
                    guard offset + if2mSize <= len else { break }
                    let if2m = baseAddr.load(as: if_msghdr2.self)
                    let upFlag = Int32(IFF_UP)
                    let loopbackFlag = Int32(IFF_LOOPBACK)
                    if (if2m.ifm_flags & upFlag) != 0 && (if2m.ifm_flags & loopbackFlag) == 0 {
                        totalReceivedBytes += if2m.ifm_data.ifi_ibytes
                        totalSentBytes += if2m.ifm_data.ifi_obytes
                    }
                }
                offset += msgLen
            }
        }
        return (totalReceivedBytes, totalSentBytes)
    }

    private enum NetworkError: Error {
        case sysctlFailed
    }
}
