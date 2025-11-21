# 代码注释规范

## 概述

本文档定义了 iMoni 项目的代码注释规范，确保代码的可读性、可维护性和团队协作效率。通过统一的注释风格和格式，帮助开发者快速理解代码结构和功能。

## 基本原则

### 1. 注释的目的

- **解释为什么**：说明代码的设计意图和业务逻辑
- **澄清复杂逻辑**：解释难以理解的算法和流程
- **提供上下文**：说明代码在整体架构中的位置和作用
- **便于维护**：帮助其他开发者快速理解和修改代码

### 2. 注释的质量要求

- **准确性**：注释内容必须与代码保持一致
- **简洁性**：避免冗余和重复信息
- **及时性**：代码修改时同步更新注释
- **可读性**：使用清晰、易懂的语言

## 文件头注释

### 基本格式

每个 Swift 文件都应该包含文件头注释：

```swift
//
//  文件名.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  文件描述：简要说明文件的主要功能和职责
//
//  功能说明：
//  - 功能点1：具体描述
//  - 功能点2：具体描述
//  - 功能点3：具体描述
//
```

### 示例

```swift
//
//  App.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  应用入口文件：负责应用生命周期管理
//
//  功能说明：
//  - 使用 SwiftUI 的 @main + App 协议作为入口
//  - 通过 AppDelegate 启动菜单栏管理器 MenuBarController
//  - 不创建主窗口，仅提供菜单栏应用形态
//
```

## MARK 注释规范

### MARK 分组结构

使用 MARK 注释组织代码结构，按以下顺序排列：

```swift
// MARK: - 导入语句
import Swift
import Foundation

// MARK: - 类型定义
class MyClass: NSObject {
    
    // MARK: - 属性
    private var property1: String = ""
    private var property2: Int = 0
    
    // MARK: - 初始化方法
    override init() {
        super.init()
        setupProperties()
    }
    
    // MARK: - 公共方法
    func publicMethod() {
        // 实现代码
    }
    
    // MARK: - 私有方法
    private func setupProperties() {
        // 实现代码
    }
    
    // MARK: - 代理方法
    func delegateMethod() {
        // 实现代码
    }
}

// MARK: - 扩展
extension MyClass {
    // 扩展方法
}
```

### MARK 命名规范

- **属性**：`// MARK: - 属性`
- **初始化方法**：`// MARK: - 初始化方法`
- **公共方法**：`// MARK: - 公共方法`
- **私有方法**：`// MARK: - 私有方法`
- **代理方法**：`// MARK: - 代理方法`
- **生命周期方法**：`// MARK: - 生命周期方法`
- **网络方法**：`// MARK: - 网络方法`
- **UI 方法**：`// MARK: - UI 方法`
- **工具方法**：`// MARK: - 工具方法`
- **扩展**：`// MARK: - 扩展`

## 文档注释规范

### 函数和方法的文档注释

使用 `///` 进行文档注释，包含参数说明和返回值说明：

```swift
/// 格式化网络速度（MB/s）
/// - Parameter speed: 网络速度（MB/s）
/// - Returns: 格式化的速度字符串，如 "12.345MB/s"
static func formatSpeed(_ speed: Double) -> String {
    return String(format: "%.3fMB/s", speed)
}
```

### 复杂方法的文档注释

对于复杂的函数，提供更详细的说明：

```swift
/// 建立 TCP 连接到指定服务端点
/// - Parameter endpoint: 要连接的服务端点
/// - Parameter timeout: 连接超时时间（秒）
/// - Parameter completion: 连接完成回调
///   - success: 连接是否成功
///   - latency: 连接延迟时间（秒），仅在成功时有效
///   - error: 连接错误，仅在失败时有效
func establishConnection(
    to endpoint: ServiceEndpoint,
    timeout: TimeInterval,
    completion: @escaping (_ success: Bool, _ latency: TimeInterval?, _ error: Error?) -> Void
) {
    // 实现代码
}
```

### 属性的文档注释

为重要的属性添加文档注释：

```swift
/// 当前监控的服务端点
/// 当用户选择不同的服务时，此属性会更新
private var currentEndpoint: ServiceEndpoint?

/// 监控器是否正在运行
/// 此属性受 NSLock 保护，确保线程安全
private(set) var isMonitoring: Bool = false
```

### 枚举的文档注释

为枚举值和枚举类型添加文档注释：

```swift
/// 连接状态枚举
/// 表示服务端点的连接状态
enum ConnectionStatus: String, CaseIterable {
    /// 已连接：服务端点可以正常访问
    case connected = "connected"
    
    /// 未连接：服务端点无法访问
    case disconnected = "disconnected"
    
    /// 连接中：正在尝试建立连接
    case connecting = "connecting"
    
    /// 连接错误：连接过程中发生错误
    case error = "error"
}
```

## 行内注释规范

### 基本格式

行内注释用于解释单行代码或简单的逻辑：

```swift
// 检查连接状态
guard isConnected else { return }

// 延迟 1 秒后重试
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
    self?.retryConnection()
}

// 过滤掉异常的速度值（超过 1000 MB/s）
if speed > maxReasonableSpeed {
    logUnreasonableSpeed(speed)
    return
}
```

### 复杂逻辑的注释

对于复杂的逻辑，使用多行注释：

```swift
// 计算网络速度：
// 1. 获取当前时间戳
// 2. 计算时间差
// 3. 计算字节差
// 4. 转换为 MB/s
let currentTime = Utilities.currentTimestamp()
let timeDiff = Utilities.timeDifference(from: lastUpdateTime)
let bytesDiff = currentBytes - lastBytes
let speedMBps = Double(bytesDiff) / (1024 * 1024) / timeDiff
```

### 临时注释

临时注释用于标记待完成或需要优化的代码：

```swift
// TODO: 优化网络请求，支持连接复用
// FIXME: 这里可能存在内存泄漏，需要进一步测试
// NOTE: 临时解决方案，后续版本会重构
// HACK: 绕过系统限制的临时方案
```

## 错误处理注释

### 错误类型注释

为错误类型添加详细的注释：

```swift
/// 监控错误枚举
/// 定义了监控过程中可能发生的所有错误类型
enum MonitorError: Error, LocalizedError {
    /// 连接超时：在指定时间内无法建立连接
    case timeout
    
    /// 连接失败：连接建立过程中发生错误
    case connectionFailed
    
    /// 网络错误：底层网络框架返回的错误
    case networkError(Error)
    
    /// 无效端点：服务端点配置不正确
    case invalidEndpoint
    
    /// 系统调用错误：sysctl 等系统调用失败
    case sysctlError(String)
}
```

### 错误处理逻辑注释

为错误处理逻辑添加注释：

```swift
private func handleError(_ error: MonitorError) {
    switch error {
    case .timeout, .connectionFailed:
        // 网络连接问题：显示离线状态，用户需要检查网络
        updateStatus(.offline)
        
    case .invalidEndpoint:
        // 配置问题：使用默认端点，避免应用崩溃
        useDefaultEndpoint()
        
    default:
        // 其他错误：记录日志，便于调试
        Utilities.debugPrint("监控错误: \(error.localizedDescription)")
    }
}
```

## 性能相关注释

### 性能优化注释

为性能优化代码添加注释：

```swift
// 使用 NSLock 保护共享状态，确保线程安全
// 性能影响：锁操作开销约 0.1 微秒，可接受
private let lock = NSLock()

// 缓存计算结果，避免重复计算
// 内存占用：约 1KB，性能提升：约 10%
private var cachedResult: CachedData?

// 使用专用队列处理配置操作，避免阻塞主线程
// 队列优先级：userInitiated，适合用户交互相关的配置
private let configQueue = DispatchQueue(
    label: "com.imoni.config",
    qos: .userInitiated
)
```

### 性能测量注释

为性能测量代码添加注释：

```swift
// 测量连接建立时间，用于性能分析和优化
let executionTime = Utilities.measureExecutionTime {
    establishConnection()
}

// 记录性能统计，帮助识别性能瓶颈
Utilities.printPerformanceStats(
    operation: "TCP 连接建立",
    executionTime: executionTime,
    additionalInfo: "端点: \(endpoint.name)"
)
```

## 线程安全注释

### 线程安全保证注释

为线程安全相关的代码添加注释：

```swift
// 此方法必须在主线程调用，用于更新 UI
// 使用 Utilities.safeMainQueueCallback 确保线程安全
func updateDisplay() {
    Utilities.safeMainQueueCallback { [weak self] in
        self?.statusItem.button?.title = self?.formattedTitle ?? ""
    }
}

// 共享状态访问受 NSLock 保护
// 确保多线程环境下的数据一致性
func updateConnectionStatus(_ status: ConnectionStatus) {
    lock.lock()
    defer { lock.unlock() }
    
    connectionStatus = status
    updateDisplay()
}
```

### 队列使用注释

为队列使用添加注释：

```swift
// 使用专用队列处理网络操作，避免阻塞主线程
// 队列特性：并发队列，支持多个网络连接同时进行
private let networkQueue = DispatchQueue(
    label: "com.imoni.network",
    qos: .userInitiated,
    attributes: .concurrent
)

// 配置操作使用串行队列，确保操作的顺序性
// 避免配置读写冲突和数据不一致
private let configQueue = DispatchQueue(
    label: "com.imoni.config",
    qos: .userInitiated
)
```

## 配置和常量注释

### 配置项注释

为配置项添加详细的注释：

```swift
/// 最大合理网络速度（MB/s）
/// 超过此值的数据被认为是异常数据，会被过滤掉
/// 设置依据：当前主流网络设备的最大理论速度约为 10Gbps = 1250 MB/s
/// 留有一定余量，设置为 1000 MB/s
private let maxReasonableSpeed: Double = 1000.0

/// 网络接口重置阈值（字节）
/// 当网络接口的字节计数小于上次记录时，认为接口被重置
/// 设置依据：1GB 是一个合理的重置阈值，避免误判
private let interfaceResetThreshold: UInt64 = 1_000_000_000

/// 连接超时时间（秒）
/// 在指定时间内无法建立连接则认为连接失败
/// 设置依据：用户体验要求，超过 0.5 秒用户会感觉响应慢
private let connectionTimeout: TimeInterval = 0.5
```

### 魔法数字注释

为魔法数字添加注释说明：

```swift
// 延迟格式化：将秒转换为毫秒显示
// 1000：1 秒 = 1000 毫秒
let latencyMs = Int(latency * 1000)

// 网络速度计算：字节转换为 MB
// 1024 * 1024：1 MB = 1024 * 1024 字节
let speedMBps = Double(bytesDiff) / (1024 * 1024) / timeDiff

// 重试延迟：使用指数退避策略
// 2.0：每次重试延迟翻倍
let retryDelay = baseDelay * pow(2.0, Double(retryCount))
```

## 测试相关注释

### 测试用例注释

为测试用例添加注释：

```swift
func testFormatLatency() {
    // 测试用例：格式化延迟时间
    // 输入：0.123 秒
    // 期望输出："123ms"
    // 验证：毫秒精度，无小数部分
    let latency: TimeInterval = 0.123
    let formatted = Utilities.formatLatency(latency)
    XCTAssertEqual(formatted, "123ms")
}

func testValidateServiceEndpoint() {
    // 测试用例：验证服务端点配置
    // 有效配置：名称、主机、端口都正确
    // 无效配置：名称为空、主机为空、端口超出范围
    let validEndpoint = ServiceEndpoint(name: "Test", host: "test.com", port: 443)
    XCTAssertTrue(Utilities.validateServiceEndpoint(validEndpoint))
    
    let invalidEndpoint = ServiceEndpoint(name: "", host: "", port: 0)
    XCTAssertFalse(Utilities.validateServiceEndpoint(invalidEndpoint))
}
```

### 测试设置注释

为测试设置添加注释：

```swift
override func setUp() {
    super.setUp()
    
    // 创建测试用的监控器实例
    // 使用模拟的代理对象，避免依赖真实网络
    monitor = MonitorLatency()
    mockDelegate = MockMonitorLatencyDelegate()
    monitor.delegate = mockDelegate
    
    // 设置测试环境
    // 使用较短的超时时间，加快测试速度
    monitor.connectionTimeout = 0.1
}

override func tearDown() {
    // 清理测试资源
    // 停止监控，释放网络连接
    monitor.cleanup()
    monitor = nil
    mockDelegate = nil
    
    super.tearDown()
}
```

## 版本和变更注释

### 版本变更注释

为重要的版本变更添加注释：

```swift
// v1.07 变更：统一使用 Utilities 工具函数
// 替换原有的直接格式化调用，提高代码一致性
// 旧代码：String(format: "%.0fms", latency)
// 新代码：Utilities.formatLatency(latency)
let formattedLatency = Utilities.formatLatency(latency)

// v1.06 变更：简化状态管理
// 从复杂的状态机改为简单的连接成功/失败状态
// 提高用户体验，减少状态混乱
private var connectionStatus: ConnectionStatus = .disconnected
```

### 兼容性注释

为兼容性相关的代码添加注释：

```swift
// 兼容性处理：macOS 15.0+ 使用新的 API
// 旧版本 macOS 使用兼容性代码
if #available(macOS 15.0, *) {
    // 使用新的 Network.framework API
    useModernNetworkAPI()
} else {
    // 使用兼容性代码
    useCompatibilityCode()
}

// 向后兼容：保留旧的配置键
// 新版本使用新的配置键，但支持导入旧配置
if let oldConfig = userDefaults.object(forKey: "oldConfigKey") {
    // 迁移旧配置到新格式
    migrateOldConfig(oldConfig)
}
```

## 注释检查清单

### 代码审查时的注释检查

在代码审查时，检查以下注释相关项目：

- [ ] 文件头注释是否完整
- [ ] MARK 注释是否合理分组
- [ ] 复杂逻辑是否有注释说明
- [ ] 公共接口是否有文档注释
- [ ] 错误处理是否有注释说明
- [ ] 性能相关代码是否有注释
- [ ] 线程安全相关代码是否有注释
- [ ] 配置和常量是否有注释
- [ ] 测试代码是否有注释
- [ ] 版本变更是否有注释

### 注释质量检查

检查注释的质量：

- [ ] 注释是否准确描述了代码功能
- [ ] 注释是否与代码保持同步
- [ ] 注释是否使用了清晰的语言
- [ ] 注释是否避免了冗余信息
- [ ] 注释是否提供了必要的上下文

## 总结

遵循本注释规范可以确保：

1. **代码可读性**：清晰的注释帮助理解代码逻辑
2. **维护效率**：详细的注释减少理解成本
3. **团队协作**：统一的注释风格便于团队协作
4. **代码质量**：注释促进代码审查和质量提升
5. **知识传承**：注释记录设计意图和业务逻辑

通过持续改进注释质量，iMoni 项目将保持高标准的代码文档，为开发者提供良好的开发体验。