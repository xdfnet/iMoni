//
//  MonitorNetwork.swift
//  Moni
//
//  Created by Moni Team
//  Copyright © 2025 Moni App. All rights reserved.
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
            lastBytesReceived = totalReceived
            lastBytesSent = totalSent
            lastUpdateTime = Utilities.currentTimestamp()
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
        lastBytesReceived = 0
        lastBytesSent = 0
        lastUpdateTime = 0
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
        let timeElapsed = Utilities.timeDifference(from: lastUpdateTime)
        
        guard timeElapsed > 0 else { return }
        
        do {
            let (currentReceived, currentSent) = try getTotalNetworkBytes()
            
            // 检查数据有效性
            guard currentReceived >= lastBytesReceived, currentSent >= lastBytesSent else {
                // 字节数减少，可能是网络接口重置，重新初始化
                logNetworkInterfaceReset()
                resetNetworkStats()
                return
            }
            
            let receivedDiff = currentReceived - lastBytesReceived
            let sentDiff = currentSent - lastBytesSent
            
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

            // 实时更新显示，不缓存
            Utilities.safeMainQueueCallback { [weak self] in
                guard let self = self else { return }
                self.delegate?.networkStats(self, didUpdateDownloadSpeed: downloadSpeedMBps, uploadSpeed: uploadSpeedMBps)
            }
            
            lastBytesReceived = currentReceived
            lastBytesSent = currentSent
            lastUpdateTime = currentTime
            
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
            lastBytesReceived = totalReceived
            lastBytesSent = totalSent
            lastUpdateTime = Utilities.currentTimestamp()
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

        // 系统调用参数 - 使用固定数组避免临时指针问题
        let mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        let ifmSize = MemoryLayout<if_msghdr>.size
        let if2mSize = MemoryLayout<if_msghdr2>.size

        // 第一次调用：获取所需缓冲区大小
        var len: size_t = 0
        
        // 使用 withUnsafeMutableBytes 安全地传递指针
        let sysctlResult = mib.withUnsafeBufferPointer { mibBuffer in
            sysctl(UnsafeMutablePointer<Int32>(mutating: mibBuffer.baseAddress), 
                   UInt32(mib.count), 
                   nil, 
                   &len, 
                   nil, 
                   0)
        }
        
        guard sysctlResult >= 0 else {
            throw NetworkError.sysctlFailed
        }

        // 分配缓冲区并获取数据
        var buffer = [CChar](repeating: 0, count: len)
        
        // 再次使用 withUnsafeMutableBytes 安全地传递指针
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

        // 解析网络接口信息
        var offset = 0
        while offset + ifmSize <= len {
            let ifm = buffer.withUnsafeBytes { ptr in
                ptr.load(fromByteOffset: offset, as: if_msghdr.self)
            }

            // 确保有足够空间读取 if_msghdr2
            if offset + if2mSize <= len && ifm.ifm_type == RTM_IFINFO2 {
                let if2m = buffer.withUnsafeBytes { ptr in
                    ptr.load(fromByteOffset: offset, as: if_msghdr2.self)
                }

                // 只考虑活跃的非回环接口
                if (if2m.ifm_flags & IFF_UP) != 0 && (if2m.ifm_flags & IFF_LOOPBACK) == 0 {
                    totalReceivedBytes += if2m.ifm_data.ifi_ibytes  // 接收字节数
                    totalSentBytes += if2m.ifm_data.ifi_obytes    // 发送字节数
                }
            }

            // 确保不越界
            guard ifm.ifm_msglen > 0 && offset + Int(ifm.ifm_msglen) <= len else {
                break
            }
            offset += Int(ifm.ifm_msglen)
        }

        return (totalReceivedBytes, totalSentBytes)
    }
    
    // MARK: - 私有错误类型
    
    private enum NetworkError: Error {
        case sysctlFailed
    }
}
