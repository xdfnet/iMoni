//
//  MonitorNetwork.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  系统级网络流量统计，计算上/下行速度（MB/s）
//
//  功能说明：
//  - 通过 sysctl 读取各网卡累计字节数，按时间差计算速率
//  - 仅统计非回环并且激活中的网卡
//  - 继承 BaseMonitor 减少代码重复
//  - 支持数据有效性检查，异常数据自动重置
//



import Foundation
import Darwin

/// 网络速率回调协议（单位：MB/s）
protocol MonitorNetworkDelegate: AnyObject {
    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double, uploadSpeed: Double) // MB/s
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus)
}

class MonitorNetwork: BaseMonitor {

    // MARK: - 属性

    weak var delegate: MonitorNetworkDelegate?

    private var lastBytesReceived: UInt64 = 0
    private var lastBytesSent: UInt64 = 0
    private var lastUpdateTime: CFAbsoluteTime = 0

    /// 线程安全锁
    private let statsLock = NSLock()
    
    // MARK: - 初始化
    
    override init(queueLabel: String, interval: TimeInterval) {
        super.init(queueLabel: queueLabel, interval: interval)
    }
    
    // MARK: - 公共方法
    
    /// 启动网络速率监控（间隔秒）
    func startMonitoring(interval: TimeInterval = MonitorConstants.defaultNetworkInterval) {
        // 初始化上次值
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

    /// 停止监控
    override func stopMonitoring() {
        super.stopMonitoring()
        statsLock.lock()
        lastBytesReceived = 0
        lastBytesSent = 0
        lastUpdateTime = 0
        statsLock.unlock()
    }
    
    // MARK: - BaseMonitor 实现
    
    override func performMonitoring() {
        updateNetworkSpeeds()
    }
    
    override func cleanupResources() {
        // 网络监控不需要特殊清理
    }
    
    // MARK: - 私有方法
    
    /// 计算下载和上传速率并回调（MB/s）
    private func updateNetworkSpeeds() {
        let currentTime = Utilities.currentTimestamp()

        // 读取上次的统计值（需要加锁）
        statsLock.lock()
        let lastTime = lastUpdateTime
        let lastReceived = lastBytesReceived
        let lastSent = lastBytesSent
        statsLock.unlock()

        let timeElapsed = currentTime - lastTime
        guard timeElapsed > 0 else { return }

        do {
            let (currentReceived, currentSent) = try getTotalNetworkBytes()

            // 检查数据有效性
            guard currentReceived >= lastReceived, currentSent >= lastSent else {
                // 字节数减少，可能是网络接口重置，重新初始化
                logNetworkInterfaceReset()
                resetNetworkStats()
                return
            }

            let receivedDiff = currentReceived - lastReceived
            let sentDiff = currentSent - lastSent

            // 转换为 MB/s (1000 * 1000 = 1,000,000 bytes per MB - 十进制标准)
            let bytesPerMB: Double = 1000.0 * 1000.0
            let downloadSpeedMBps = Double(receivedDiff) / timeElapsed / bytesPerMB
            let uploadSpeedMBps = Double(sentDiff) / timeElapsed / bytesPerMB

            // 验证速度值的合理性
            guard downloadSpeedMBps >= 0 && downloadSpeedMBps <= MonitorConstants.maxReasonableSpeed,
                  uploadSpeedMBps >= 0 && uploadSpeedMBps <= MonitorConstants.maxReasonableSpeed else {
                logUnreasonableSpeed(downloadSpeedMBps)
                resetNetworkStats()
                return
            }

            // 更新统计值（需要加锁）
            statsLock.lock()
            lastBytesReceived = currentReceived
            lastBytesSent = currentSent
            lastUpdateTime = currentTime
            statsLock.unlock()

            // 实时更新显示，不缓存
            Utilities.safeMainQueueCallback { [weak self] in
                guard let self = self else { return }
                self.delegate?.networkStats(self, didUpdateDownloadSpeed: downloadSpeedMBps, uploadSpeed: uploadSpeedMBps)
            }

        } catch {
            Utilities.safeMainQueueCallback { [weak self] in
                guard let self = self else { return }
                self.delegate?.networkStats(self, didFailWithError: ConnectionStatus.disconnected)
            }

            logNetworkError(error)
        }
    }
    
    /// 重置网络统计
    private func resetNetworkStats() {
        do {
            let (totalReceived, totalSent) = try getTotalNetworkBytes()
            statsLock.lock()
            lastBytesReceived = totalReceived
            lastBytesSent = totalSent
            lastUpdateTime = Utilities.currentTimestamp()
            statsLock.unlock()
        } catch {
            logNetworkError(error)
        }
    }
    
    /// 记录网络接口重置
    private func logNetworkInterfaceReset() {
        #if DEBUG
        Utilities.debugPrint("Network interface reset detected, reinitializing stats")
        #endif
    }
    
    /// 记录不合理的速度值
    private func logUnreasonableSpeed(_ speed: Double) {
        #if DEBUG
        Utilities.debugPrint("Unreasonable speed detected: \(Utilities.formatSpeed(speed))")
        #endif
    }
    
    /// 记录网络错误
    private func logNetworkError(_ error: Error) {
        #if DEBUG
        Utilities.debugPrint("Network error: \(error.localizedDescription)")
        #endif
    }
    
    /// 汇总所有有效网卡的累计上/下行字节数
    private func getTotalNetworkBytes() throws -> (received: UInt64, sent: UInt64) {
        var totalReceivedBytes: UInt64 = 0
        var totalSentBytes: UInt64 = 0

        // 系统调用参数
        let mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]

        // 结构体大小常量
        let ifmSize = MemoryLayout<if_msghdr>.size
        let if2mSize = MemoryLayout<if_msghdr2>.size
        // 合理的最大消息长度（防止恶意数据）
        let maxMessageSize = 65536

        // 第一次调用：获取所需缓冲区大小
        var len: size_t = 0

        let sysctlResult = mib.withUnsafeBufferPointer { mibBuffer in
            sysctl(UnsafeMutablePointer<Int32>(mutating: mibBuffer.baseAddress),
                   UInt32(mib.count),
                   nil,
                   &len,
                   nil,
                   0)
        }

        guard sysctlResult >= 0, len > 0 else {
            throw NetworkError.sysctlFailed
        }

        // 分配缓冲区并获取数据
        var buffer = [CChar](repeating: 0, count: len)

        let sysctlResult2 = mib.withUnsafeBufferPointer { mibBuffer in
            sysctl(UnsafeMutablePointer<Int32>(mutating: mibBuffer.baseAddress),
                   UInt32(mib.count),
                   &buffer,
                   &len,
                   nil,
                   0)
        }

        guard sysctlResult2 >= 0 else {
            throw NetworkError.sysctlFailed
        }

        // 安全解析网络接口信息
        buffer.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            var offset = 0

            while offset < len {
                // 确保有足够空间读取基本头部
                guard offset + ifmSize <= len else { break }

                // 安全读取 if_msghdr 头部
                let baseAddr = rawPtr.baseAddress!.advanced(by: offset)
                let ifm = baseAddr.load(as: if_msghdr.self)
                let msgLen = Int(ifm.ifm_msglen)

                // 验证消息长度合理性
                guard msgLen >= ifmSize, msgLen <= maxMessageSize,
                      offset + msgLen <= len else {
                    break
                }

                // 只处理 RTM_IFINFO2 类型消息
                if ifm.ifm_type == RTM_IFINFO2 {
                    // 确保有足够空间读取完整的 if_msghdr2
                    guard offset + if2mSize <= len else { break }

                    // 安全读取 if_msghdr2
                    let if2m = baseAddr.load(as: if_msghdr2.self)

                    // 只考虑活跃的非回环接口
                    let upFlag = Int32(IFF_UP)
                    let loopbackFlag = Int32(IFF_LOOPBACK)

                    if (if2m.ifm_flags & upFlag) != 0 &&
                       (if2m.ifm_flags & loopbackFlag) == 0 {
                        totalReceivedBytes += if2m.ifm_data.ifi_ibytes
                        totalSentBytes += if2m.ifm_data.ifi_obytes
                    }
                }

                offset += msgLen
            }
        }

        return (totalReceivedBytes, totalSentBytes)
    }
    
    // MARK: - 私有错误类型
    
    private enum NetworkError: Error {
        case sysctlFailed
    }
}
