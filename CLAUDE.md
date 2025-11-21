# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

iMoni 是一个 macOS 菜单栏应用，用于实时监控 AI 服务的网络延迟和系统网络流量。采用 SwiftUI + Swift 5.0 开发，支持多种监控模式和可配置的监控间隔。项目经过 v1.17 版本的重大更新，完成项目重命名和构建系统优化，提高了代码质量和可维护性。

## 常用开发命令

### 构建和部署
```bash
# 完整构建（包含版本号递增）
make build

# 固定版本构建（不递增版本）
make build-fixed

# 清理构建文件
make clean

# 查看所有可用命令
make help
```

### 代码质量检查
```bash
# 运行代码质量检查脚本
./Scripts/code_quality_check.sh

# 或使用 Makefile
make quality-check
```

### 开发工具
```bash
# 打开 Xcode 项目
open iMoni.xcodeproj

# 构建（Xcode）
xcodebuild -project iMoni.xcodeproj -scheme iMoni -configuration Debug build

# 发布构建
xcodebuild -project iMoni.xcodeproj -scheme iMoni -configuration Release build
```

## 项目架构

### 分层架构设计

项目采用四层架构：

1. **应用层 (Application Layer)**
   - `App.swift`: 应用入口点和生命周期管理
   - `MenuBarController.swift`: 菜单栏控制器和用户界面

2. **业务逻辑层 (Business Logic Layer)**
   - `BaseMonitor.swift`: 基础监控抽象类
   - `MonitorLatency.swift`: TCP 延迟监控实现
   - `MonitorNetwork.swift`: 系统网络流量监控

3. **服务层 (Service Layer)**
   - `ServiceManager.swift`: 服务端点管理和分类
   - `ConfigurationManager.swift`: 用户配置管理

4. **基础设施层 (Infrastructure Layer)**
   - `SharedTypes.swift`: 共享类型定义和常量
   - `Utilities.swift`: 统一工具函数库

### 关键设计模式

- **代理模式**: `MonitorLatencyDelegate`, `MonitorNetworkDelegate`
- **观察者模式**: 状态变化通知
- **策略模式**: 不同监控策略（延迟 vs 网络监控）
- **模板方法模式**: `BaseMonitor` 定义监控流程
- **单例模式**: `ServiceManager.shared`, `ConfigurationManager.shared`

### 核心组件说明

#### App.swift
- 职责：应用生命周期管理，系统事件监听（睡眠/唤醒）
- 设计特点：使用 SwiftUI 的 `@main` 协议，通过 `AppDelegate` 管理应用状态
- 重要功能：菜单栏管理器初始化，系统睡眠/唤醒事件处理

#### MenuBarController.swift
- 职责：状态栏图标显示和管理，用户菜单界面，监控状态协调
- 设计特点：协调 `MonitorLatency` 与 `MonitorNetwork` 的启停，动态菜单创建
- 重要功能：显示模式切换（Service/Network），监控间隔配置，服务选择菜单

#### BaseMonitor.swift
- 职责：定义监控基础流程，提供通用的资源管理，支持可配置的监控间隔
- 设计特点：抽象基类，定义监控接口，使用模板方法模式
- 核心方法：`startMonitoring()`, `stopMonitoring()`, `cleanup()`, `performMonitoring()`

#### MonitorLatency.swift
- 职责：TCP 连接延迟测量，连接状态管理，延迟数据回调
- 技术实现：使用 Network.framework 建立 TCP 连接，测量连接建立时间
- 设计特点：继承 `BaseMonitor` 基类，使用代理模式通知结果

#### MonitorNetwork.swift
- 职责：系统网络流量统计，下载速度计算，网络接口状态监控
- 技术实现：通过 sysctl 获取网络统计信息，计算单位时间内的数据变化
- 设计特点：智能过滤网络接口，数据有效性验证，自动重置异常统计

#### ServiceManager.swift
- 职责：服务端点配置管理，服务分类组织，端点验证
- 设计特点：单例模式，全局访问，按类别组织服务
- 服务分类：AI 服务、开发工具、网络服务

#### ConfigurationManager.swift
- 职责：用户配置持久化，配置导入导出，配置变更通知
- 设计特点：使用 UserDefaults 存储配置，支持 JSON 格式导入导出
- 配置项：显示模式选择、监控间隔设置、服务选择偏好、通知设置

#### Utilities.swift
- 职责：提供通用工具函数，统一常用功能，减少代码重复
- 功能分类：格式化工具、时间工具、线程安全工具、数值工具、性能工具、调试工具
- 重要函数：`formatLatency`, `formatSpeed`, `safeMainQueueCallback`, `currentTimestamp`

## 关键文件和功能

### 配置文件
- `Info.plist`: 应用配置，包含版本号、权限等
- `iMoni.entitlements`: 应用权限配置
- `Makefile`: 构建自动化脚本

### 核心源文件
- `SharedTypes.swift`: 共享类型定义和常量（ServiceEndpoint, ConnectionStatus, MonitorConstants）
- `Utilities.swift`: 统一工具函数库（格式化、时间处理、线程安全、数值处理、性能测量、调试）
- `ConfigurationManager.swift`: 配置管理和验证

### 文档目录 `Docs/`
- `README.md`: 项目概述和快速开始指南
- `CHANGELOG.md`: 版本更新日志
- `ARCHITECTURE.md`: 详细架构文档
- `DEVELOPMENT.md`: 开发指南
- `FEATURES.md`: 功能特性说明
- `API_REFERENCE.md`: API 参考文档
- `COMMENT_STANDARDS.md`: 代码注释标准

## 开发规范

### 代码风格
- 遵循 Swift API Design Guidelines
- 使用统一的注释风格（参考 `Docs/COMMENT_STANDARDS.md`）
- 支持中文注释
- 完整的错误处理和日志记录

### 工具函数使用规范
- **统一使用 Utilities**：所有常用功能都应使用 `Utilities.swift` 中的函数
- **格式化函数**：`formatLatency`, `formatSpeed`, `formatInterval`
- **时间工具**：`currentTimestamp`, `timeDifference`
- **线程安全工具**：`safeMainQueueCallback`
- **数值工具**：`safeInt`, `clamp`, `validateServiceEndpoint`
- **性能工具**：`measureExecutionTime`
- **调试工具**：`debugPrint`, `printPerformanceStats`

### 文件组织
- 每个文件不超过 500 行
- 相关功能组织在同一个文件中
- 使用 `// MARK:` 注释组织代码
- 使用扩展分离不同功能

### 命名约定
- 类名：PascalCase（如 `MenuBarController`）
- 方法名：camelCase（如 `startMonitoring`）
- 属性名：camelCase（如 `isMonitoring`）
- 常量名：camelCase（如 `maxRetryCount`）

## 状态管理

### 连接状态
- 简化的状态管理：连接成功/失败两种状态
- 状态指示：成功显示数值，失败显示 `--`
- 系统睡眠/唤醒支持：自动重建状态栏和恢复监控

### 监控模式
- `DisplayMode.service`: AI 服务延迟监控
- `DisplayMode.network`: 网络流量监控
- 通过菜单切换模式，自动启停对应监控器

### 监控频率
- 0.5 秒：高频监控，适合调试
- 1.0 秒：标准监控，平衡性能和准确性
- 2.0 秒：低频监控，减少系统资源占用
- 5.0 秒：超低频监控，适合长期观察

## 错误处理

### 错误类型 (SharedTypes.swift)
```swift
enum MonitorError: Error, LocalizedError {
    case timeout              // 连接超时
    case connectionFailed     // 连接失败
    case networkError(Error)  // 网络错误
    case invalidEndpoint      // 无效端点
    case sysctlError(String)  // 系统调用错误
}

enum NetworkError: Error, LocalizedError {
    case interfaceNotFound    // 未找到网络接口
    case invalidData         // 无效的网络数据
    case calculationError    // 网络速度计算错误
}
```

### 错误处理策略
- 使用代理模式通知错误
- 简化重试逻辑，避免复杂的状态处理
- 数据验证：过滤无效数据，异常数据自动重置
- 降级处理：网络不可用时显示离线状态，配置错误时使用默认值

## 线程安全

### 保护机制
- `NSLock`: 保护监控状态（BaseMonitor）
- 专用队列：配置操作专用队列（ConfigurationManager）
- 主线程回调：统一使用 `Utilities.safeMainQueueCallback` 确保主线程回调

### 异步处理
- 后台队列：监控操作在后台执行
- 主队列：UI 更新在主队列执行
- 队列隔离：不同监控器使用独立队列

### 线程安全工具
- `Utilities.safeMainQueueCallback(_:)`：安全的主线程回调执行
- `Utilities.safeMainQueueCallback<T>(_:)`：带 weak self 检查的主线程回调

## 服务端点配置

### 预配置服务

#### AI 服务
- **Claude** (api.anthropic.com) - Anthropic 的 AI 助手
- **Gemini** (generativelanguage.googleapis.com) - Google 的 AI 模型
- **DeepSeek** (api.deepseek.com) - DeepSeek 的 AI 服务
- **GLM** (open.bigmodel.cn) - 智谱 AI 的 GLM 模型
- **Qwen** (dashscope.aliyuncs.com) - 阿里云的 AI 模型
- **Kimi** (api.moonshot.cn) - 月之暗面的 AI 助手

#### IDE 服务
- **Cursor** (api.cursor.sh) - AI 编程工具中转服务
- **Visual Studio Code** (marketplace.visualstudio.com) - 微软的代码编辑器
- **Windsurf** (api.windsurf.sh) - Web 集成开发环境

#### 开发工具
- **Homebrew** (formulae.brew.sh) - macOS 包管理器
- **NPM** (registry.npmjs.org) - Node.js 包管理器
- **PyPI** (pypi.org) - Python 包管理器
- **Maven** (repo1.maven.org) - Java 包管理器

#### 网络服务
- **Docker Hub** (registry-1.docker.io) - 容器镜像仓库

## 扩展开发

### 添加新的监控类型
1. 继承 `BaseMonitor`
2. 实现 `performMonitoring()` 和 `cleanup()` 方法
3. 在 `MenuBarController` 中实现对应的代理协议
4. 更新菜单和状态管理

### 添加新的服务端点
1. 在 `ServiceManager` 中添加配置
2. 更新菜单显示逻辑
3. 支持用户自定义端点配置

### 添加新的配置项
1. 在 `ConfigurationManager` 中定义
2. 添加验证逻辑
3. 更新 UI 配置界面

## 测试和调试

### 调试工具
- `Utilities.debugPrint()`: 调试输出（包含文件名、行号、函数名）
- `Utilities.measureExecutionTime()`: 性能测量
- `Utilities.printPerformanceStats()`: 性能统计

### 性能优化
- 定时器优化：设置合理的容差值
- 连接复用：避免重复连接
- 内存管理：及时释放不需要的资源
- 线程安全：使用 NSLock 和专用队列

### 常见问题
- 编译错误：检查 Swift 版本兼容性
- 内存泄漏：使用 Instruments 工具检测
- 构建问题：清理构建文件后重试 (`make clean`)
- 环境变量：确保 Homebrew 环境正确配置
- 网络权限：系统偏好设置 → 安全性与隐私 → 网络，确保应用有网络访问权限

### 测试
虽然没有传统的单元测试框架，但可以通过以下方式进行验证：
- 构建验证：`make build` 确保项目能正常构建
- 代码质量检查：`make quality-check` 运行自动化检查
- 手动测试：应用启动后验证菜单栏功能和监控状态

## 环境配置

### 终端配置
- 推荐使用 zsh 作为默认终端
- 确保 Homebrew 环境变量正确配置
- 在 `~/.zshrc` 中添加：`eval "$(/opt/homebrew/bin/brew shellenv)"`

### IDE 配置
- **Cursor**: 配置为使用 zsh 终端，支持 Homebrew
- **VSCode**: 配置为使用 zsh 终端，统一开发体验
- 自动识别 Homebrew 安装的 Python 3.13.7

## 最新更新 (v1.17)

### 项目重命名
- **品牌统一**：项目名称从 Moni 改为 iMoni，统一品牌标识
- **仓库迁移**：GitHub 仓库地址更新为 https://github.com/xdfnet/iMoni.git
- **文档同步**：所有文档和配置文件中的项目名称已同步更新

### 构建系统优化
- **Makefile 修复**：修复版本更新功能的路径配置问题
- **版本管理**：改进版本号解析逻辑，增强边界情况处理
- **构建流程**：优化构建步骤，提高构建稳定性和兼容性

### 代码结构优化
- 删除了重复和未使用的函数，提高代码质量
- 统一工具函数库：所有格式化、时间处理、调试都使用 `Utilities` 工具库
- 线程安全优化：统一使用 `Utilities.safeMainQueueCallback` 确保主线程回调安全

### 环境变量继承
- 修复了终端环境变量配置，支持 zsh 和 bash
- Python 路径优化：自动识别并使用 Homebrew 安装的 Python 3.13.7
- 终端配置统一：Cursor 和 VSCode 都配置为使用 zsh 终端

### 代码质量提升
- 遵循 Swift 最佳实践，注释完整，结构清晰
- 删除未使用代码：清理了 `ServiceManager` 中未使用的方法
- 优化网络监控：改进了 `MonitorNetwork.swift` 中的错误处理和代码结构
- 延迟监控优化：修复了 `MonitorLatency.swift` 中的缩进和主线程回调问题

## 注意事项

1. **始终使用 Utilities 工具函数**：避免直接使用 `print`, `DispatchQueue.main.async` 等
2. **线程安全**：使用 `Utilities.safeMainQueueCallback` 进行主线程回调
3. **格式化函数**：使用 `Utilities.formatLatency`, `Utilities.formatSpeed` 等
4. **时间工具**：使用 `Utilities.currentTimestamp`, `Utilities.timeDifference` 等
5. **调试输出**：使用 `Utilities.debugPrint` 而不是 `print`
6. **代码组织**：使用 MARK 注释进行合理的代码分组
7. **错误处理**：遵循统一的错误处理模式
8. **配置管理**：通过 `ConfigurationManager` 管理所有配置

通过遵循这些指导原则，可以确保代码的一致性和质量，提高开发效率和项目可维护性。