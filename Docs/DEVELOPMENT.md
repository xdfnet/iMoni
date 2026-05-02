# 开发指南

## 概述

本文档为 iMoni 项目的开发者提供详细的开发指南，包括环境配置、代码规范、构建流程、测试策略等。通过遵循这些指南，确保代码质量、可维护性和团队协作效率。

## 开发环境

### 系统要求

- **操作系统**：macOS 15.0 或更高版本
- **开发工具**：Xcode 15.0 或更高版本
- **编程语言**：Swift 5.0
- **目标平台**：macOS 15.0+

### 环境配置

#### 1. 终端配置

推荐使用 zsh 作为默认终端：

```bash
# 检查当前 shell
echo $SHELL

# 如果显示 /bin/zsh，说明已经是 zsh
# 如果需要切换到 zsh
chsh -s /bin/zsh
```

#### 2. Homebrew 配置

确保 Homebrew 环境变量正确配置：

```bash
# 在 ~/.zshrc 中添加
eval "$(/opt/homebrew/bin/brew shellenv)"

# 重新加载配置
source ~/.zshrc
```

#### 3. IDE 配置

**Cursor 配置** (`~/Library/Application Support/Cursor/User/settings.json`)：
```json
{
    "terminal.integrated.defaultProfile.osx": "zsh",
    "terminal.integrated.profiles.osx": {
        "zsh": {
            "path": "zsh",
            "args": ["-l"]
        }
    },
    "terminal.integrated.inheritEnv": true,
    "terminal.integrated.shellIntegration.enabled": true,
    "python.defaultInterpreterPath": "/opt/homebrew/bin/python3"
}
```

**VSCode 配置** (`~/Library/Application Support/Code/User/settings.json`)：
```json
{
    "terminal.integrated.defaultProfile.osx": "zsh",
    "terminal.integrated.profiles.osx": {
        "zsh": {
            "path": "/bin/zsh",
            "args": ["-l"]
        }
    }
}
```

## 项目结构

### 目录组织

```text
iMoni/
├── Moni/                    # 主要源代码
│   ├── App.swift           # 应用入口点和生命周期管理
│   ├── MenuBarController.swift  # 菜单栏控制器和用户界面
│   ├── BaseMonitor.swift   # 基础监控抽象类
│   ├── MonitorLatency.swift    # TCP 延迟监控实现
│   ├── MonitorNetwork.swift    # 系统网络流量监控
│   ├── ServiceManager.swift    # 服务端点管理和分类
│   ├── ConfigurationManager.swift # 用户配置管理
│   ├── SharedTypes.swift   # 共享类型定义和常量
│   └── Utilities.swift     # 统一工具函数库
├── Scripts/                 # 构建和检查脚本
│   └── code_quality_check.sh # 代码质量检查
├── Docs/                    # 项目文档
├── Assets.xcassets/         # 应用资源
└── Makefile                 # 构建自动化脚本
```

### 文件命名规范

- **Swift 文件**：使用 PascalCase，如 `MenuBarController.swift`
- **资源文件**：使用 PascalCase，如 `Assets.xcassets`
- **脚本文件**：使用 snake_case，如 `code_quality_check.sh`
- **文档文件**：使用 UPPER_CASE，如 `README.md`

## 代码规范

### Swift 编码规范

#### 1. 命名约定

- **类型名**：使用 PascalCase
- **变量和函数名**：使用 camelCase
- **常量**：使用 camelCase
- **枚举值**：使用 camelCase

```swift
// 正确的命名
class MenuBarController { }
struct ServiceEndpoint { }
enum ConnectionStatus { }
var currentLatency: TimeInterval = 0
func startMonitoring() { }

// 错误的命名
class menubarcontroller { }
struct service_endpoint { }
enum CONNECTION_STATUS { }
var CurrentLatency: TimeInterval = 0
func StartMonitoring() { }
```

#### 2. 注释规范

使用 MARK 注释组织代码结构：

```swift
// MARK: - 属性
private var isMonitoring: Bool = false
private var currentEndpoint: ServiceEndpoint?

// MARK: - 生命周期方法
func applicationDidFinishLaunching(_ notification: Notification) {
    // 实现代码
}

// MARK: - 私有方法
private func setupMenuBar() {
    // 实现代码
}
```

#### 3. 代码组织

每个文件按以下顺序组织：

1. 文件头注释
2. import 语句
3. 类型定义
4. MARK 分组
5. 属性
6. 初始化方法
7. 公共方法
8. 私有方法
9. 扩展

### 工具函数使用规范

#### 1. 统一使用 Utilities

所有常用功能都应使用 `Utilities.swift` 中的函数：

```swift
// 正确的用法
let formattedLatency = Utilities.formatLatency(latency)
let currentTime = Utilities.currentTimestamp()
Utilities.safeMainQueueCallback { [weak self] in
    self?.updateDisplay()
}

// 错误的用法
let formattedLatency = String(format: "%.0fms", latency)
let currentTime = CFAbsoluteTimeGetCurrent()
DispatchQueue.main.async { [weak self] in
    self?.updateDisplay()
}
```

#### 2. 格式化函数

- **延迟格式化**：`Utilities.formatLatency(_:)`
- **速度格式化**：`Utilities.formatSpeed(_:)`
- **间隔格式化**：`Utilities.formatInterval(_:)`

#### 3. 时间工具

- **当前时间戳**：`Utilities.currentTimestamp()`
- **时间差计算**：`Utilities.timeDifference(from:)`

#### 4. 线程安全工具

- **主线程回调**：`Utilities.safeMainQueueCallback(_:)`
- **带 weak self 的主线程回调**：`Utilities.safeMainQueueCallback<T>(_:)`

## 构建系统

### Makefile 使用

#### 基本命令

```bash
# 查看所有可用命令
make help

# 完整构建（包含版本号递增）
make build

# 固定版本构建（不递增版本）
make build-fixed

# 清理构建文件
make clean

# 代码质量检查
make quality-check
```

#### 构建流程

1. **清理控制台** - 清屏准备
2. **关闭应用** - 检测并关闭运行中的应用
3. **更新版本** - 自动递增版本号和构建号
4. **构建应用** - 使用 Release 配置构建
5. **安装应用** - 安装到 /Applications
6. **清理文件** - 删除构建临时文件
7. **打开应用** - 自动启动新应用

### Xcode 构建

#### 项目配置

1. 打开 `iMoni.xcodeproj`
2. 选择正确的目标设备（macOS）
3. 选择 Release 配置进行生产构建

#### 构建快捷键

- **Cmd + B**：构建项目
- **Cmd + R**：运行项目
- **Cmd + Shift + K**：清理构建文件

## 代码质量检查

### 自动化检查

#### 运行检查脚本

```bash
# 运行代码质量检查
make quality-check

# 或直接运行脚本
./Scripts/code_quality_check.sh
```

#### 检查内容

- 语法检查
- 代码格式验证
- 最佳实践检查
- 潜在问题识别

### 手动检查

#### 编译警告

确保构建时没有编译警告：

```bash
# 构建并检查警告
xcodebuild -project iMoni.xcodeproj -scheme iMoni -configuration Release build
```

#### 代码审查清单

- [ ] 遵循命名规范
- [ ] 使用正确的 MARK 注释
- [ ] 使用 Utilities 工具函数
- [ ] 避免重复代码
- [ ] 正确处理内存管理
- [ ] 线程安全考虑

## 测试策略

### 单元测试

#### 测试框架

使用 XCTest 框架编写测试：

```swift
import XCTest
@testable import iMoni

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
}
```

#### 测试覆盖

- 工具函数测试
- 数据验证测试
- 格式化函数测试
- 错误处理测试

#### 当前覆盖率快照（2026-05-02）

执行命令：

```bash
xcodebuild -project iMoni.xcodeproj -scheme iMoni -destination 'platform=macOS' -derivedDataPath build/DerivedData -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY='' test
xcrun xccov view --report build/DerivedData/Logs/Test/Test-iMoni-2026.05.02_12-18-01-+0800.xcresult
```

结果摘要：

- 单元测试：`105/105` 通过
- 主目标覆盖率（`iMoni.app`）：`52.85%`（`594/1124`）

主要文件覆盖率：

- `ServiceManager.swift`：`97.96%`
- `MonitorLatency.swift`：`80.00%`
- `Utilities.swift`：`72.62%`
- `BaseMonitor.swift`：`70.67%`
- `App.swift`：`63.33%`
- `ConfigurationManager.swift`：`55.63%`
- `MenuBarController.swift`：`53.16%`
- `SharedTypes.swift`：`25.00%`

### 集成测试

#### 测试场景

- 监控流程完整性
- 组件间交互
- 配置变更处理
- 错误恢复机制

#### 测试环境

- 模拟网络环境
- 模拟系统状态
- 自动化测试脚本

### 性能测试

#### 测试指标

- 内存使用量
- CPU 占用率
- 网络性能
- 响应时间

#### 测试工具

- Instruments 性能分析
- 压力测试脚本
- 性能基准测试

## 调试技巧

### 日志输出

#### 使用 Utilities.debugPrint

```swift
// 正确的调试输出
Utilities.debugPrint("开始监控服务: \(endpoint.name)")

// 错误的调试输出
print("开始监控服务: \(endpoint.name)")
```

#### 性能测量

```swift
// 测量代码执行时间
let executionTime = Utilities.measureExecutionTime {
    // 要测量的代码
    performExpensiveOperation()
}
Utilities.debugPrint("操作耗时: \(executionTime) 秒")
```

### 断点调试

#### 关键断点位置

- 监控启动/停止
- 网络连接建立
- 数据回调处理
- 配置变更处理

#### 条件断点

设置条件断点以捕获特定情况：

```swift
// 只在特定条件下触发断点
endpoint.name == "Claude" && latency > 1000
```

## 版本管理

### 版本号规范

遵循语义化版本控制：

- **主版本号**：重大功能更新或架构变更
- **次版本号**：新功能添加或重要改进
- **修订版本号**：问题修复和小幅优化

### 版本更新流程

1. 更新 `Info.plist` 中的版本号
2. 更新 `README.md` 中的版本徽章
3. 更新 `Docs/CHANGELOG.md`
4. 提交版本更新
5. 创建版本标签

### Git 工作流

#### 分支策略

- **main**：主分支，包含稳定版本
- **develop**：开发分支，集成新功能
- **feature/***：功能分支，开发新功能
- **hotfix/***：热修复分支，修复紧急问题

#### 提交规范

使用清晰的提交信息：

```
feat: 添加新的 AI 服务监控支持
fix: 修复网络监控中的异常数据处理
docs: 更新 API 参考文档
refactor: 重构工具函数库结构
test: 添加延迟监控单元测试
```

## 性能优化

### 内存管理

#### 避免循环引用

```swift
// 正确的用法
Utilities.safeMainQueueCallback { [weak self] in
    self?.updateDisplay()
}

// 错误的用法
Utilities.safeMainQueueCallback { [weak self] in
    self?.updateDisplay()
    // 可能导致循环引用
}
```

#### 及时释放资源

```swift
func cleanup() {
    // 停止定时器
    timer?.invalidate()
    timer = nil
    
    // 清理网络连接
    connection?.cancel()
    connection = nil
    
    // 重置状态
    isMonitoring = false
}
```

### 网络优化

#### 连接管理

- 设置合理的超时时间
- 避免重复连接
- 及时释放连接资源

#### 数据验证

- 过滤异常数据
- 验证数据范围
- 处理网络接口重置

## 错误处理

### 错误类型定义

```swift
enum MonitorError: Error, LocalizedError {
    case timeout
    case connectionFailed
    case networkError(Error)
    case invalidEndpoint
    case sysctlError(String)
    
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
        }
    }
}
```

### 错误处理策略

#### 重试机制

```swift
private func retryConnection() {
    guard retryCount < maxRetryCount else {
        handleConnectionFailure(.timeout)
        return
    }
    
    retryCount += 1
    DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) { [weak self] in
        self?.establishConnection()
    }
}
```

#### 降级处理

```swift
private func handleError(_ error: MonitorError) {
    switch error {
    case .timeout, .connectionFailed:
        // 显示离线状态
        updateStatus(.offline)
    case .invalidEndpoint:
        // 使用默认端点
        useDefaultEndpoint()
    default:
        // 记录错误日志
        Utilities.debugPrint("监控错误: \(error.localizedDescription)")
    }
}
```

## 扩展开发

### 添加新监控类型

#### 1. 继承 BaseMonitor

```swift
class NewMonitor: BaseMonitor {
    
    override func performMonitoring() {
        // 实现具体的监控逻辑
    }
    
    override func cleanup() {
        // 清理资源
    }
}
```

#### 2. 实现代理协议

```swift
protocol NewMonitorDelegate: AnyObject {
    func monitor(_ monitor: NewMonitor, didUpdateData data: Data)
    func monitor(_ monitor: NewMonitor, didFailWithError error: Error)
}
```

#### 3. 集成到菜单控制器

```swift
// 在 MenuBarController 中添加
private var newMonitor: NewMonitor?

private func setupNewMonitor() {
    newMonitor = NewMonitor()
    newMonitor?.delegate = self
}
```

### 添加新服务端点

#### 1. 在 ServiceManager 中注册

```swift
// 在 ServiceManager 中添加新服务
static let newServices: [ServiceEndpoint] = [
    ServiceEndpoint(name: "NewService", host: "api.newservice.com", port: 443)
]
```

#### 2. 更新菜单显示

```swift
// 在 MenuBarController 中添加菜单项
private func createNewServiceMenu() -> NSMenu {
    let menu = NSMenu()
    // 添加菜单项
    return menu
}
```

## 部署和发布

### 构建生产版本

```bash
# 构建生产版本
make build

# 验证构建产物
ls -la /Applications/iMoni.app
```

### 发布检查清单

- [ ] 所有测试通过
- [ ] 代码质量检查通过
- [ ] 版本号正确更新
- [ ] 文档同步更新
- [ ] 构建产物验证
- [ ] 安装测试通过

## 常见问题

### 编译问题

#### 找不到 Homebrew 命令

```bash
# 解决方案：加载 Homebrew 环境
eval "$(/opt/homebrew/bin/brew shellenv)"
```

#### 找不到 Python 解释器

确保 IDE 配置正确的 Python 路径：

```json
{
    "python.defaultInterpreterPath": "/opt/homebrew/bin/python3"
}
```

### 运行时问题

#### 网络权限问题

确保应用有网络访问权限：
- 系统偏好设置 → 安全性与隐私 → 网络
- 添加 iMoni 应用

#### 状态栏不显示

检查应用是否被隐藏：
- 确保应用没有被隐藏到 Dock
- 检查状态栏是否被系统隐藏

## 总结

遵循本开发指南可以确保：

1. **代码质量**：统一的编码规范和最佳实践
2. **团队协作**：清晰的开发流程和标准
3. **可维护性**：良好的代码组织和文档
4. **性能优化**：合理的资源管理和优化策略
5. **扩展性**：支持新功能和监控类型的扩展

通过持续改进和优化，iMoni 项目将保持高质量、高性能和良好的用户体验。
