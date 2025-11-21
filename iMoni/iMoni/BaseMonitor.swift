//
//  BaseMonitor.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  基础监控类：提供通用的监控功能
//
//  功能说明：
//  - 减少 MonitorLatency 和 MonitorNetwork 的代码重复
//  - 提供统一的资源管理和错误处理
//  - 支持可配置的监控间隔
//

import Foundation

// MARK: - 基础监控协议
protocol BaseMonitorProtocol: AnyObject {
    var isMonitoring: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    func cleanup()
}

// MARK: - 基础监控类
class BaseMonitor: BaseMonitorProtocol {
    
    // MARK: - 属性
    
    /// 监控状态
    private(set) var isMonitoring: Bool = false
    
    /// 监控定时器
    internal var monitorTimer: Timer?
    
    /// 后台队列
    internal let queue: DispatchQueue
    
    /// 监控间隔
    internal var monitoringInterval: TimeInterval
    

    
    /// 监控状态锁（线程安全）
    private let monitoringLock = NSLock()
    
    // MARK: - 初始化
    
    init(queueLabel: String, interval: TimeInterval) {
        self.queue = DispatchQueue(label: queueLabel, qos: .utility)
        self.monitoringInterval = interval
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - 公共方法
    
    /// 开始监控
    func startMonitoring() {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startTimer()
    }
    
    /// 停止监控
    func stopMonitoring() {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        
        guard isMonitoring else { return }
        
        stopTimer()
        isMonitoring = false
    }
    
    /// 清理资源
    func cleanup() {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        
        stopTimer()
        isMonitoring = false
        cleanupResources()
    }
    
    /// 更新监控间隔
    func updateInterval(_ newInterval: TimeInterval) {
        monitoringLock.lock()
        defer { monitoringLock.unlock() }
        
        // 验证间隔值
        let validatedInterval = max(MonitorConstants.minInterval, 
                                  min(newInterval, MonitorConstants.maxInterval))
        
        monitoringInterval = validatedInterval
        
        if isMonitoring {
            restartTimer()
        }
    }
    
    // MARK: - 私有方法
    
    /// 启动定时器
    private func startTimer() {
        stopTimer() // 确保先停止之前的定时器
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.performMonitoring()
            }
        }
        
        // 设置定时器的容差，提高系统性能
        monitorTimer?.tolerance = min(monitoringInterval * 0.1, 0.1)
    }
    
    /// 停止定时器
    private func stopTimer() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    /// 重启定时器
    private func restartTimer() {
        if isMonitoring {
            startTimer()
        }
    }
    
    // MARK: - 子类需要实现的方法
    
    /// 执行具体的监控逻辑（子类必须实现）
    func performMonitoring() {
        fatalError("子类必须实现 performMonitoring() 方法")
    }
    
    /// 清理具体资源（子类可以重写）
    func cleanupResources() {
        // 默认实现为空，子类可以重写
    }
}


