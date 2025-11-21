//
//  MonitorLatency.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  TCP 探活与延迟测量（毫秒）
//
//  功能说明：
//  - 通过 Network.framework 建立到目标主机端口的 TCP 连接
//  - 连接 ready 的时间差即为近似网络时延
//  - 内置超时处理，失败时通过代理上报连接状态
//  - 支持系统睡眠/唤醒后的自动恢复
//

import Foundation
import Network

/// 监控结果回调协议
protocol MonitorLatencyDelegate: AnyObject {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint)
}

class MonitorLatency: BaseMonitor {
    
    // MARK: - 属性
    
    weak var delegate: MonitorLatencyDelegate?
    
    private var currentEndpoint: ServiceEndpoint?
    private var currentConnection: NWConnection?
    
    // MARK: - 初始化
    
    override init(queueLabel: String, interval: TimeInterval) {
        super.init(queueLabel: queueLabel, interval: interval)
    }
    
    // MARK: - 公共方法
    
    /// 开始监控指定端点
    func startMonitoring(_ endpoint: ServiceEndpoint) {
        stopMonitoring()
        currentEndpoint = endpoint
        
        super.startMonitoring()
        // 立即触发一次监控，避免等待首个定时器周期
        queue.async { [weak self] in
            self?.performMonitoring()
        }
    }
    
    /// 停止监控并重置状态
    override func stopMonitoring() {
        super.stopMonitoring()
        cleanupCurrentConnection()
        currentEndpoint = nil
    }
    
    // MARK: - BaseMonitor 实现
    
    override func performMonitoring() {
        guard let endpoint = currentEndpoint else { return }
        
        // 避免重复连接
        guard currentConnection == nil else { return }
        
        pingEndpoint(endpoint)
    }
    
    override func cleanupResources() {
        cleanupCurrentConnection()
    }
    
    // MARK: - 私有方法
    
    /// 执行一次 TCP 探测并计算时延
    private func pingEndpoint(_ endpoint: ServiceEndpoint) {
        let startTime = Utilities.currentTimestamp()
        
        // 创建连接
        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(endpoint.port)),
            using: .tcp
        )
        
        currentConnection = connection
        connection.start(queue: queue)
        
        // 设置超时处理：使用统一常量
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.handleConnectionTimeout(for: endpoint, startTime: startTime)
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + MonitorConstants.connectionTimeout, execute: timeoutWorkItem)
        
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(state, for: endpoint, startTime: startTime, timeoutWorkItem: timeoutWorkItem)
        }
    }
    
    /// 处理连接状态变化
    private func handleConnectionStateChange(_ state: NWConnection.State, for endpoint: ServiceEndpoint, startTime: CFAbsoluteTime, timeoutWorkItem: DispatchWorkItem) {
        switch state {
        case .ready:
            timeoutWorkItem.cancel()
            let latency = Utilities.timeDifference(from: startTime)
            handleSuccessfulConnection(latency: latency, for: endpoint)
            
        case .failed(_):
            timeoutWorkItem.cancel()
            handleConnectionFailure(for: endpoint)
            
        case .cancelled:
            timeoutWorkItem.cancel()
            // 连接被取消，不需要特殊处理
            
        case .waiting, .preparing, .setup:
            // 连接准备中，正常状态，无需处理
            break
            
        @unknown default:
            // 处理未来可能的新状态
            logUnknownConnectionState(state, for: endpoint)
        }
    }
    
    /// 处理连接成功
    private func handleSuccessfulConnection(latency: TimeInterval, for endpoint: ServiceEndpoint) {
        cleanupCurrentConnection()
        
        Utilities.safeMainQueueCallback { [weak self] in
            guard let self = self else { return }
            self.delegate?.monitor(self, didUpdateLatency: latency, for: endpoint)
        }
    }
    
    /// 处理连接超时
    private func handleConnectionTimeout(for endpoint: ServiceEndpoint, startTime: CFAbsoluteTime) {
        cleanupCurrentConnection()
        handleConnectionFailure(for: endpoint)
    }
    
    /// 处理连接失败
    private func handleConnectionFailure(for endpoint: ServiceEndpoint) {
        cleanupCurrentConnection()

        Utilities.safeMainQueueCallback { [weak self] in
            guard let self = self else { return }
            self.delegate?.monitor(self, didFailWithError: ConnectionStatus.disconnected, for: endpoint)
        }

        logConnectionFailure(for: endpoint)
    }
    
    /// 清理当前连接
    private func cleanupCurrentConnection() {
        currentConnection?.cancel()
        currentConnection = nil
    }
    
    /// 记录未知连接状态
    private func logUnknownConnectionState(_ state: NWConnection.State, for endpoint: ServiceEndpoint) {
        #if DEBUG
        Utilities.debugPrint("Unknown connection state for \(endpoint.name): \(state)")
        #endif
    }
    
    /// 记录连接失败
    private func logConnectionFailure(for endpoint: ServiceEndpoint) {
        #if DEBUG
        Utilities.debugPrint("Connection failed for \(endpoint.name)")
        #endif
    }
}