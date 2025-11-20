# API 参考

## 概述

本文档提供了 iMoni 项目的完整 API 参考，包括所有公开的类、协议、方法和属性。通过详细的文档说明和代码示例，帮助开发者理解和使用 iMoni 的各个组件。

## 核心类型

### App.swift

#### iMoniApp

主应用结构，使用 SwiftUI 的 `@main` 协议。

```swift
@main
struct iMoniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

#### AppDelegate

应用代理类，负责应用生命周期管理。

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarController?
    private var sleepObservers: [Any] = []
    
    func applicationDidFinishLaunching(_ notification: Notification)
    func applicationWillTerminate(_ notification: Notification)
}
```

**方法说明：**

- `applicationDidFinishLaunching(_:)`：应用启动完成回调，初始化菜单栏管理器并设置系统事件监听
- `applicationWillTerminate(_:)`：应用即将退出回调，清理资源和移除事件监听

### MenuBarController.swift

#### MenuBarController

菜单栏控制器，负责状态栏显示和用户界面管理。

```swift
class MenuBarController: NSObject {
    // 监控器
    private var latencyMonitor: MonitorLatency?
    private var networkMonitor: MonitorNetwork?
    
    // 状态管理
    private var currentDisplayMode: DisplayMode = .service
    private var currentService: ServiceEndpoint?
    private var currentRate: MonitorRate = .oneSecond
}
```

**主要方法：**

```swift
// 初始化
init()

// 显示模式管理
func switchToServiceMode()
func switchToNetworkMode()

// 监控管理
func startLatencyMonitoring(for endpoint: ServiceEndpoint)
func startNetworkMonitoring()
func stopAllMonitoring()

// 状态更新
func updateDisplay(with latency: TimeInterval)
func updateDisplay(with speed: Double)
func updateConnectionStatus(_ status: ConnectionStatus)

// 资源管理
func cleanup()
func suspend()
func resumeAfterWake()
```

**代理协议：**

```swift
extension MenuBarController: MonitorLatencyDelegate {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError error: MonitorError, for endpoint: ServiceEndpoint)
}

extension MenuBarController: MonitorNetworkDelegate {
    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double, uploadSpeed: Double)
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus)
}
```

### BaseMonitor.swift

#### BaseMonitor

基础监控抽象类，定义监控器的通用接口和实现。

```swift
class BaseMonitor: NSObject {
    // 监控状态
    private(set) var isMonitoring: Bool = false
    
    // 配置
    var monitorInterval: TimeInterval = 1.0
    var isEnabled: Bool = true
    
    // 内部状态
    private var timer: Timer?
    private let lock = NSLock()
}
```

**主要方法：**

```swift
// 监控控制
func startMonitoring()
func stopMonitoring()
func cleanup()

// 子类重写
func performMonitoring()
```

**协议定义：**

```swift
protocol BaseMonitorProtocol: AnyObject {
    var isMonitoring: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    func cleanup()
}
```

### MonitorLatency.swift

#### MonitorLatency

TCP 连接延迟监控器，继承自 `BaseMonitor`。

```swift
class MonitorLatency: BaseMonitor {
    // 代理
    weak var delegate: MonitorLatencyDelegate?
    
    // 当前监控端点
    private var currentEndpoint: ServiceEndpoint?
    
    // 连接管理
    private var connection: NWConnection?
    private var connectionTimeout: TimeInterval = 0.5
}
```

**主要方法：**

```swift
// 监控控制
func startMonitoring(for endpoint: ServiceEndpoint)
func stopMonitoring()

// 连接管理
private func establishConnection()
private func handleConnectionStateChange(_ state: NWConnection.State)
private func handleSuccessfulConnection()
private func handleConnectionFailure(_ error: MonitorError)

// 资源清理
override func cleanup()
```

**代理协议：**

```swift
protocol MonitorLatencyDelegate: AnyObject {
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint)
    func monitor(_ monitor: MonitorLatency, didFailWithError error: MonitorError, for endpoint: ServiceEndpoint)
}
```

### MonitorNetwork.swift

#### MonitorNetwork

系统网络流量监控器，继承自 `BaseMonitor`。

```swift
class MonitorNetwork: BaseMonitor {
    // 代理
    weak var delegate: MonitorNetworkDelegate?
    
    // 网络统计
    private var lastUpdateTime: CFAbsoluteTime = 0
    private var lastBytesReceived: UInt64 = 0
    
    // 配置
    private let maxReasonableSpeed: Double = 1000.0 // MB/s
    private let interfaceResetThreshold: UInt64 = 1_000_000_000 // 1GB
}
```

**主要方法：**

```swift
// 监控控制
func startMonitoring()
func stopMonitoring()

// 网络统计
private func getTotalNetworkBytes() -> UInt64
private func updateNetworkSpeeds()
private func resetNetworkStats()
private func logUnreasonableSpeed(_ speed: Double)

// 资源清理
override func cleanup()
```

**代理协议：**

```swift
protocol MonitorNetworkDelegate: AnyObject {
    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double, uploadSpeed: Double)
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus)
}
```

**方法说明：**
- `networkStats(_:didUpdateDownloadSpeed:uploadSpeed:)`: 当网络速度更新时调用。`downloadSpeed` 和 `uploadSpeed` 分别提供了实时的下行和上行速度（单位: MB/s）。
- `networkStats(_:didFailWithError:)`: 当监控发生错误时调用。

### ServiceManager.swift

#### ServiceManager

服务端点管理器，负责服务配置和分类管理。

```swift
class ServiceManager {
    // 单例实例
    static let shared = ServiceManager()
    
    // 服务分类
    static let aiServices: [ServiceEndpoint]
    static let developmentServices: [ServiceEndpoint]
    static let networkServices: [ServiceEndpoint]
    
    private init() {}
}
```

**服务端点配置：**

```swift
// AI 服务
static let aiServices: [ServiceEndpoint] = [
    ServiceEndpoint(name: "Claude", host: "api.anthropic.com", port: 443),
    ServiceEndpoint(name: "Gemini", host: "generativelanguage.googleapis.com", port: 443),
    ServiceEndpoint(name: "DeepSeek", host: "api.deepseek.com", port: 443),
    ServiceEndpoint(name: "GLM", host: "open.bigmodel.cn", port: 443),
    ServiceEndpoint(name: "Kimi", host: "api.moonshot.cn", port: 443)
]

// 开发工具
static let developmentServices: [ServiceEndpoint] = [
    ServiceEndpoint(name: "Homebrew", host: "formulae.brew.sh", port: 443),
    ServiceEndpoint(name: "NPM", host: "registry.npmjs.org", port: 443),
    ServiceEndpoint(name: "PyPI", host: "pypi.org", port: 443),
    ServiceEndpoint(name: "Maven", host: "repo1.maven.org", port: 443)
]

// 网络服务
static let networkServices: [ServiceEndpoint] = [
    ServiceEndpoint(name: "Docker Hub", host: "registry-1.docker.io", port: 443),
    ServiceEndpoint(name: "Cursor", host: "api.cursor.sh", port: 443)
]
```

**主要方法：**

```swift
// 服务获取
func getServices(for category: ServiceCategory) -> [ServiceEndpoint]
func getAllServices() -> [ServiceEndpoint]

// 服务验证
func validateEndpoint(_ endpoint: ServiceEndpoint) -> Bool
```

### ConfigurationManager.swift

#### ConfigurationManager

配置管理器，负责用户配置的持久化和管理。

```swift
class ConfigurationManager {
    // 单例实例
    static let shared = ConfigurationManager()
    
    // 配置存储
    private let userDefaults = UserDefaults.standard
    private let configQueue = DispatchQueue(label: "com.moni.config", qos: .userInitiated)
    
    private init() {}
}
```

**配置键定义：**

```swift
private enum ConfigKeys {
    static let displayMode = "displayMode"
    static let monitorRate = "monitorRate"
    static let selectedService = "selectedService"
    static let notificationsEnabled = "notificationsEnabled"
}
```

**主要方法：**

```swift
// 配置读写
var displayMode: DisplayMode
var monitorRate: MonitorRate
var selectedService: ServiceEndpoint?
var notificationsEnabled: Bool

// 配置管理
func resetToDefaults()
func exportConfiguration() -> Data?
func importConfiguration(_ data: Data) -> Bool

// 通知
private func notifyConfigurationChanged()
```

### SharedTypes.swift

#### ServiceEndpoint

服务端点结构，定义服务的基本信息。

```swift
struct ServiceEndpoint: Codable, Equatable {
    let name: String
    let host: String
    let port: Int
    
    init(name: String, host: String, port: Int)
}
```

**属性说明：**

- `name`：服务名称，用于显示和标识
- `host`：服务主机地址
- `port`：服务端口号

#### ConnectionStatus

连接状态枚举，表示服务的连接状态。

```swift
enum ConnectionStatus: String, CaseIterable {
    case connected = "connected"
    case disconnected = "disconnected"
    case connecting = "connecting"
    case error = "error"
}
```

#### MonitorRate

监控频率枚举，定义可选的监控间隔。

```swift
enum MonitorRate: TimeInterval, CaseIterable {
    case halfSecond = 0.5
    case oneSecond = 1.0
    case twoSeconds = 2.0
    case fiveSeconds = 5.0
    
    var displayName: String
}
```

#### DisplayMode

显示模式枚举，定义应用的显示状态。

```swift
enum DisplayMode: String, CaseIterable {
    case service = "service"
    case network = "network"
    
    var displayName: String
}
```

#### ServiceCategory

服务分类枚举，用于组织不同类型的服务。

```swift
enum ServiceCategory: String, CaseIterable {
    case ai = "ai"
    case development = "development"
    case network = "network"
    case custom = "custom"  // 新增分类
    
    var displayName: String {
        switch self {
        case .custom:
            return "自定义服务"
        // ... 其他分类
        }
    }
}
```

#### MonitorConstants

监控相关常量定义。

```swift
struct MonitorConstants {
    static let defaultTimeout: TimeInterval = 3.0
    static let maxRetryCount = 3
    static let retryDelay: TimeInterval = 1.0
    static let connectionTimeout: TimeInterval = 0.5
}
```

#### AppConstants

应用常量定义。

```swift
struct AppConstants {
    static let appName = "iMoni"
    static let appVersion = "1.07"
    static let defaultValue = "--"
    static let maxDisplayLength = 20
}
```

### Utilities.swift

#### Utilities

工具函数库，提供常用的工具函数和辅助方法。

```swift
class Utilities {
    // 私有初始化器，防止实例化
    private init() {}
}
```

**格式化工具：**

```swift
/// 格式化延迟时间（毫秒）
/// - Parameter latency: 延迟时间（秒）
/// - Returns: 格式化的延迟字符串，如 "123ms"
static func formatLatency(_ latency: TimeInterval) -> String

/// 格式化网络速度（MB/s）
/// - Parameter speed: 网络速度（MB/s）
/// - Returns: 格式化的速度字符串，如 "12.345MB/s"
static func formatSpeed(_ speed: Double) -> String

/// 格式化时间间隔
/// - Parameter interval: 时间间隔（秒）
/// - Returns: 格式化的间隔字符串，如 "1.0s"
static func formatInterval(_ interval: TimeInterval) -> String
```

**时间工具：**

```swift
/// 获取当前时间戳
/// - Returns: 当前时间戳（CFAbsoluteTime）
static func currentTimestamp() -> CFAbsoluteTime

/// 计算时间差
/// - Parameter from: 起始时间戳
/// - Returns: 时间差（秒）
static func timeDifference(from startTime: CFAbsoluteTime) -> TimeInterval
```

**线程安全工具：**

```swift
/// 安全的主线程回调执行
/// - Parameter closure: 要在主线程执行的闭包
static func safeMainQueueCallback(_ closure: @escaping () -> Void)

/// 带 weak self 检查的主线程回调
/// - Parameters:
///   - object: 要检查的对象
///   - closure: 要在主线程执行的闭包
static func safeMainQueueCallback<T: AnyObject>(_ object: T, closure: @escaping (T) -> Void)
```

**数值工具：**

```swift
/// 安全的整数转换
/// - Parameter string: 要转换的字符串
/// - Returns: 转换后的整数，失败时返回 0
static func safeInt(_ string: String) -> Int

/// 限制数值范围
/// - Parameters:
///   - value: 要限制的数值
///   - min: 最小值
///   - max: 最大值
/// - Returns: 限制后的数值
static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T

/// 验证服务端点配置
/// - Parameter endpoint: 要验证的服务端点
/// - Returns: 验证结果，true 表示配置有效
static func validateServiceEndpoint(_ endpoint: ServiceEndpoint) -> Bool
```

**性能工具：**

```swift
/// 测量代码执行时间
/// - Parameter operation: 要测量的操作
/// - Returns: 执行时间（秒）
static func measureExecutionTime(_ operation: () -> Void) -> TimeInterval

/// 异步测量代码执行时间
/// - Parameters:
///   - operation: 要测量的异步操作
///   - completion: 完成回调，返回执行时间
static func measureExecutionTimeAsync(_ operation: @escaping (@escaping () -> Void) -> Void, completion: @escaping (TimeInterval) -> Void)
```

**调试工具：**

```swift
/// 打印调试信息（包含文件名、行号、函数名）
/// - Parameters:
///   - message: 调试消息
///   - file: 文件名（自动获取）
///   - function: 函数名（自动获取）
///   - line: 行号（自动获取）
static func debugPrint(_ message: String, file: String = #file, function: String = #function, line: Int = #line)

/// 打印性能统计信息
/// - Parameters:
///   - operation: 操作名称
///   - executionTime: 执行时间
///   - additionalInfo: 附加信息
static func printPerformanceStats(operation: String, executionTime: TimeInterval, additionalInfo: String? = nil)
```

## 错误处理

### MonitorError

监控错误枚举，定义所有可能的监控错误。

```swift
enum MonitorError: Error, LocalizedError {
    case timeout
    case connectionFailed
    case networkError(Error)
    case invalidEndpoint
    case sysctlError(String)
    case configurationError(String)
    case resourceError(String)
}
```

**错误描述：**

```swift
var errorDescription: String? {
    switch self {
    case .timeout:
        return "连接超时"
    case .connectionFailed:
        return "连接失败"
    case .networkError(let error):
        return "网络错误: \(error.localizedDescription)"
    case .invalidEndpoint:
        return "无效的服务端点"
    case .sysctlError(let message):
        return "系统调用错误: \(message)"
    case .configurationError(let message):
        return "配置错误: \(message)"
    case .resourceError(let message):
        return "资源错误: \(message)"
    }
}
```

### NetworkError

网络错误枚举，用于网络监控中的特定错误。

```swift
enum NetworkError: Error, LocalizedError {
    case interfaceNotFound
    case invalidData
    case calculationError
    
    var errorDescription: String? {
        switch self {
        case .interfaceNotFound:
            return "未找到网络接口"
        case .invalidData:
            return "无效的网络数据"
        case .calculationError:
            return "网络速度计算错误"
        }
    }
}
```

## 配置管理

### 用户默认值

iMoni 使用 `UserDefaults` 存储用户配置，所有配置键都以 `com.imoni` 为前缀。

**配置项：**

- `displayMode`：显示模式（service/network）
- `monitorRate`：监控频率（0.5/1.0/2.0/5.0 秒）
- `selectedService`：选中的服务端点
- `notificationsEnabled`：通知开关

**配置持久化：**

```swift
// 读取配置
let displayMode = ConfigurationManager.shared.displayMode

// 写入配置
ConfigurationManager.shared.displayMode = .network

// 重置配置
ConfigurationManager.shared.resetToDefaults()

// 导入导出配置
let configData = ConfigurationManager.shared.exportConfiguration()
let success = ConfigurationManager.shared.importConfiguration(configData)
```

## 监控配置

### 延迟监控配置

**超时设置：**

```swift
// 连接超时时间
let connectionTimeout: TimeInterval = 0.5

// 监控间隔
let monitorInterval: TimeInterval = 1.0

// 重试次数
let maxRetryCount = 3
```

**端点配置：**

```swift
// 创建自定义端点
let customEndpoint = ServiceEndpoint(
    name: "Custom Service",
    host: "api.customservice.com",
    port: 443
)

// 验证端点配置
let isValid = Utilities.validateServiceEndpoint(customEndpoint)
```

### 网络监控配置

**速度阈值：**

```swift
// 最大合理速度
let maxReasonableSpeed: Double = 1000.0 // MB/s

// 接口重置阈值
let interfaceResetThreshold: UInt64 = 1_000_000_000 // 1GB
```

**数据验证：**

```swift
// 过滤异常数据
if speed > maxReasonableSpeed {
    logUnreasonableSpeed(speed)
    return
}

// 检测接口重置
if bytesReceived < lastBytesReceived {
    resetNetworkStats()
}
```

## 线程安全

### 锁机制

iMoni 使用 `NSLock` 保护共享状态：

```swift
class BaseMonitor: NSObject {
    private let lock = NSLock()
    
    func startMonitoring() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isMonitoring else { return }
        isMonitoring = true
        // 启动监控逻辑
    }
}
```

### 队列管理

使用专用队列处理特定操作：

```swift
class ConfigurationManager {
    private let configQueue = DispatchQueue(
        label: "com.moni.config",
        qos: .userInitiated
    )
    
    func saveConfiguration() {
        configQueue.async {
            // 配置保存逻辑
        }
    }
}
```

### 主线程回调

统一使用 `Utilities.safeMainQueueCallback` 确保主线程回调：

```swift
// 正确的用法
Utilities.safeMainQueueCallback { [weak self] in
    self?.updateDisplay()
}

// 带 weak self 检查的用法
Utilities.safeMainQueueCallback(self) { [weak self] in
    self?.updateDisplay()
}
```

## 性能优化

### 内存管理

**避免循环引用：**

```swift
// 使用 weak 引用
weak var delegate: MonitorLatencyDelegate?

// 在闭包中使用 weak self
Utilities.safeMainQueueCallback { [weak self] in
    self?.updateDisplay()
}
```

**及时释放资源：**

```swift
func cleanup() {
    // 停止定时器
    timer?.invalidate()
    timer = nil
    
    // 取消网络连接
    connection?.cancel()
    connection = nil
    
    // 重置状态
    isMonitoring = false
}
```

### 网络优化

**连接管理：**

```swift
// 设置合理的超时时间
let connection = NWConnection(
    host: NWEndpoint.Host(endpoint.host),
    port: NWEndpoint.Port(integerLiteral: UInt16(endpoint.port))
)

// 设置连接超时
connection.start(queue: .global())
```

**数据验证：**

```swift
// 过滤异常数据
guard speed >= 0 && speed <= maxReasonableSpeed else {
    Utilities.debugPrint("异常速度值: \(speed)")
    return
}

// 检测网络接口重置
if bytesReceived < lastBytesReceived {
    Utilities.debugPrint("检测到网络接口重置")
    resetNetworkStats()
}
```

## 扩展开发

### 添加新监控类型

**1. 继承 BaseMonitor：**

```swift
class CustomMonitor: BaseMonitor {
    override func performMonitoring() {
        // 实现具体的监控逻辑
        Utilities.debugPrint("执行自定义监控")
        
        // 通知结果
        delegate?.monitor(self, didUpdateResult: result)
    }
    
    override func cleanup() {
        // 清理资源
        super.cleanup()
    }
}
```

**2. 实现代理协议：**

```swift
protocol CustomMonitorDelegate: AnyObject {
    func monitor(_ monitor: CustomMonitor, didUpdateResult result: CustomResult)
    func monitor(_ monitor: CustomMonitor, didFailWithError error: Error)
}
```

**3. 集成到菜单控制器：**

```swift
extension MenuBarController: CustomMonitorDelegate {
    private var customMonitor: CustomMonitor?
    
    private func setupCustomMonitor() {
        customMonitor = CustomMonitor()
        customMonitor?.delegate = self
    }
    
    func monitor(_ monitor: CustomMonitor, didUpdateResult result: CustomResult) {
        // 处理监控结果
        updateDisplay(with: result)
    }
}
```

### 添加新服务端点

**1. 在 ServiceManager 中注册：**

```swift
extension ServiceManager {
    static let customServices: [ServiceEndpoint] = [
        ServiceEndpoint(name: "Custom API", host: "api.custom.com", port: 443),
        ServiceEndpoint(name: "Test Service", host: "test.service.com", port: 8080)
    ]
}
```

**2. 更新服务分类：**

```swift
enum ServiceCategory: String, CaseIterable {
    case ai = "ai"
    case development = "development"
    case network = "network"
    case custom = "custom"  // 新增分类
    
    var displayName: String {
        switch self {
        case .custom:
            return "自定义服务"
        // ... 其他分类
        }
    }
}
```

**3. 更新菜单显示：**

```swift
private func createCustomServiceMenu() -> NSMenu {
    let menu = NSMenu()
    
    for service in ServiceManager.customServices {
        let item = NSMenuItem(
            title: service.name,
            action: #selector(selectCustomService(_:)),
            keyEquivalent: ""
        )
        item.representedObject = service
        menu.addItem(item)
    }
    
    return menu
}
```

## 测试支持

### 单元测试

**测试工具函数：**

```swift
class UtilitiesTests: XCTestCase {
    func testFormatLatency() {
        let latency: TimeInterval = 0.123
        let formatted = Utilities.formatLatency(latency)
        XCTAssertEqual(formatted, "123ms")
    }
    
    func testFormatSpeed() {
        let speed: Double = 12.345
        let formatted = Utilities.formatSpeed(speed)
        XCTAssertEqual(formatted, "12.345MB/s")
    }
    
    func testValidateServiceEndpoint() {
        let validEndpoint = ServiceEndpoint(name: "Test", host: "test.com", port: 443)
        XCTAssertTrue(Utilities.validateServiceEndpoint(validEndpoint))
        
        let invalidEndpoint = ServiceEndpoint(name: "", host: "", port: 0)
        XCTAssertFalse(Utilities.validateServiceEndpoint(invalidEndpoint))
    }
}
```

**测试监控器：**

```swift
class MonitorLatencyTests: XCTestCase {
    var monitor: MonitorLatency!
    var mockDelegate: MockMonitorLatencyDelegate!
    
    override func setUp() {
        super.setUp()
        monitor = MonitorLatency()
        mockDelegate = MockMonitorLatencyDelegate()
        monitor.delegate = mockDelegate
    }
    
    func testStartMonitoring() {
        let endpoint = ServiceEndpoint(name: "Test", host: "test.com", port: 443)
        monitor.startMonitoring(for: endpoint)
        
        XCTAssertTrue(monitor.isMonitoring)
    }
}
```

### 集成测试

**测试监控流程：**

```swift
class MonitorIntegrationTests: XCTestCase {
    func testCompleteMonitoringFlow() {
        let menuController = MenuBarController()
        let endpoint = ServiceManager.shared.aiServices.first!
        
        // 启动延迟监控
        menuController.startLatencyMonitoring(for: endpoint)
        
        // 等待监控结果
        let expectation = XCTestExpectation(description: "监控完成")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
}
```

## 调试支持

### 日志输出

**使用 Utilities.debugPrint：**

```swift
// 基本调试信息
Utilities.debugPrint("开始监控服务: \(endpoint.name)")

// 性能信息
Utilities.debugPrint("连接建立耗时: \(latency)ms")

// 错误信息
Utilities.debugPrint("监控失败: \(error.localizedDescription)")
```

**性能测量：**

```swift
// 测量函数执行时间
let executionTime = Utilities.measureExecutionTime {
    performExpensiveOperation()
}
Utilities.debugPrint("操作耗时: \(executionTime) 秒")

// 异步性能测量
Utilities.measureExecutionTimeAsync({ completion in
    performAsyncOperation {
        completion()
    }
}) { executionTime in
    Utilities.debugPrint("异步操作耗时: \(executionTime) 秒")
}
```

### 状态检查

**监控状态：**

```swift
// 检查监控器状态
if latencyMonitor.isMonitoring {
    Utilities.debugPrint("延迟监控正在运行")
}

// 检查连接状态
switch connectionStatus {
case .connected:
    Utilities.debugPrint("服务连接正常")
case .disconnected:
    Utilities.debugPrint("服务连接断开")
case .connecting:
    Utilities.debugPrint("正在连接服务")
case .error:
    Utilities.debugPrint("服务连接错误")
}
```

## 总结

iMoni 的 API 设计遵循以下原则：

1. **一致性**：所有组件使用统一的接口和命名规范
2. **可扩展性**：支持新监控类型和服务端点的添加
3. **线程安全**：使用适当的锁机制和队列管理
4. **错误处理**：完善的错误类型和处理机制
5. **性能优化**：内存管理和网络优化的最佳实践
6. **测试支持**：完整的测试框架和调试工具

通过遵循这些 API 设计原则，iMoni 提供了稳定、高效、易用的网络监控解决方案。
