//
//  Utilities.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  工具类：提供常用的辅助功能
//
//  功能说明：
//  - 统一格式化、验证等常用功能
//  - 提供线程安全的回调执行
//  - 减少代码重复
//  - 包含格式化工具、时间工具、线程安全工具、数值工具、性能工具和调试工具
//

import Foundation

// MARK: - 工具类
struct Utilities {
    
    // MARK: - 格式化工具
    
    /// 格式化延迟时间（毫秒）
    /// - Parameter latency: 延迟时间（秒）
    /// - Returns: 格式化的延迟字符串，如 "150ms"
    static func formatLatency(_ latency: TimeInterval) -> String {
        let latencyMs = latency * 1000
        return String(format: "%.0fms", latencyMs)
    }
    
    /// 格式化网络速度（MB/s）
    /// - Parameter speed: 网络速度（MB/s）
    /// - Returns: 格式化的速度字符串，如 "12.34MB/s"
    static func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.2fMB/s", speed)
    }
    
    /// 格式化时间间隔
    /// - Parameter interval: 时间间隔（秒）
    /// - Returns: 格式化的时间字符串，如 "0.5s", "1s", "5s"
    static func formatInterval(_ interval: TimeInterval) -> String {
        if interval < 1.0 {
            return "\(interval)s"
        } else if interval == 1.0 {
            return "1s"
        } else {
            return "\(Int(interval))s"
        }
    }
    
    // MARK: - 时间工具
    
    /// 获取当前时间戳
    /// - Returns: 当前时间戳（CFAbsoluteTime）
    static func currentTimestamp() -> CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent()
    }
    
    /// 计算时间差
    /// - Parameter startTime: 开始时间戳
    /// - Returns: 从开始时间到现在的时间差（秒）
    static func timeDifference(from startTime: CFAbsoluteTime) -> TimeInterval {
        return currentTimestamp() - startTime
    }
    
    // MARK: - 线程安全工具
    
    /// 安全的主线程回调执行
    /// - Parameter callback: 要在主线程执行的闭包
    static func safeMainQueueCallback(_ callback: @escaping () -> Void) {
        if Thread.isMainThread {
            callback()
        } else {
            DispatchQueue.main.async(execute: callback)
        }
    }
    
    /// 带 weak self 检查的主线程回调
    /// - Parameters:
    ///   - object: 要弱引用的对象
    ///   - callback: 要在主线程执行的闭包，参数为强引用的对象
    static func safeMainQueueCallback<T: AnyObject>(_ object: T, _ callback: @escaping (T) -> Void) {
        safeMainQueueCallback { [weak object] in
            guard let object = object else { return }
            callback(object)
        }
    }
    
    // MARK: - 数值工具
    
    /// 安全的数值转换
    /// - Parameters:
    ///   - value: 要转换的值
    ///   - defaultValue: 转换失败时的默认值
    /// - Returns: 转换后的整数值
    static func safeInt(_ value: Any?, defaultValue: Int = 0) -> Int {
        if let intValue = value as? Int {
            return intValue
        } else if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue
        } else if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        return defaultValue
    }
    
    /// 限制数值范围
    /// - Parameters:
    ///   - value: 要限制的值
    ///   - min: 最小值
    ///   - max: 最大值
    /// - Returns: 限制在 [min, max] 范围内的值
    static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        return Swift.max(min, Swift.min(value, max))
    }
    
    // MARK: - 验证工具
    
    /// 验证服务端点配置
    /// - Parameter endpoint: 要验证的服务端点
    /// - Returns: 验证结果，true 表示配置有效
    static func validateServiceEndpoint(_ endpoint: ServiceEndpoint) -> Bool {
        return !endpoint.name.isEmpty && 
               !endpoint.host.isEmpty && 
               endpoint.port > 0 && 
               endpoint.port <= 65535
    }
    
    // MARK: - 性能工具
    
    /// 测量代码执行时间
    /// - Parameter operation: 要测量的操作
    /// - Returns: 包含结果和执行时间的元组
    static func measureExecutionTime<T>(_ operation: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = currentTimestamp()
        let result = try operation()
        let duration = currentTimestamp() - startTime
        return (result, duration)
    }
    
    // MARK: - 调试工具
    
    /// 打印调试信息（仅在 DEBUG 模式下）
    /// - Parameters:
    ///   - message: 调试消息
    ///   - file: 调用文件（自动获取）
    ///   - function: 调用函数（自动获取）
    ///   - line: 调用行号（自动获取）
    static func debugPrint(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("[\(fileName):\(line)] \(function): \(message)")
        #endif
    }
    
    /// 打印性能统计
    /// - Parameters:
    ///   - name: 操作名称
    ///   - duration: 执行时间（秒）
    static func printPerformanceStats(_ name: String, duration: TimeInterval) {
        #if DEBUG
        print("⏱️ [\(name)] Duration: \(String(format: "%.3f", duration))s")
        #endif
    }
}

