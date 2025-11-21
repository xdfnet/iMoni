# iMoni - AI 服务延迟监控工具

[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15.0+-blue.svg)](https://developer.apple.com/macos/)
[![Version](https://img.shields.io/badge/Version-1.26-green.svg)](https://github.com/xdfnet/iMoni)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 项目简介

iMoni 是一个轻量级的 macOS 菜单栏应用，专门用于实时监控 AI 服务的网络延迟和系统网络流量。通过优化的代码结构、统一的工具函数库和现代化的架构设计，为开发者提供可靠的网络监控体验。

## 主要特性

### 核心功能

- **AI 服务延迟监控**：实时测量各种 AI 服务的网络延迟（毫秒精度）
- **网络流量监控**：监控系统网络上/下行速度（MB/s，三位小数精度）
- **延迟高亮**：延迟超过阈值时以不同颜色显示，提供即时视觉警报
- **菜单栏集成**：轻量级设计，不占用桌面空间
- **可配置监控间隔**：支持 0.5s、1s、2s、5s 多种频率

### 最新功能 (v1.26)

- **代码结构优化**：删除了重复和未使用的函数，提高代码质量
- **统一工具函数库**：所有格式化、时间处理、调试都使用 `Utilities` 工具库
- **线程安全优化**：统一使用 `Utilities.safeMainQueueCallback` 确保主线程回调安全
- **环境变量继承**：修复了终端环境变量配置，支持 zsh 和 bash
- **Python 路径优化**：自动识别并使用 Homebrew 安装的 Python 3.13.7
- **终端配置统一**：Cursor 和 VSCode 都配置为使用 zsh 终端
- **代码质量提升**：遵循 Swift 最佳实践，注释完整，结构清晰

### 服务支持

#### AI 服务

- **OpenAI** (api.openai.com)
- **Claude** (api.anthropic.com)
- **Gemini** (generativelanguage.googleapis.com)
- **DeepSeek** (api.deepseek.com)
- **GLM** (open.bigmodel.cn)
- **Qwen** (dashscope.aliyuncs.com)
- **Kimi** (api.moonshot.cn)

#### IDE 服务

- **Cursor** (api.cursor.sh)
- **Visual Studio Code** (marketplace.visualstudio.com)
- **Windsurf** (api.windsurf.sh)

#### 开发工具

- **Homebrew** (formulae.brew.sh)
- **NPM** (registry.npmjs.org)
- **PyPI** (pypi.org)
- **Maven** (repo1.maven.org)

#### 网络服务

- **Docker Hub** (registry-1.docker.io)

## 快速开始

### 环境要求

- 操作系统：macOS 15.0 或更高版本
- 开发工具：Xcode 15.0 或更高版本
- 编程语言：Swift 5.0
- 目标平台：macOS 15.0+
- 推荐终端：zsh（系统默认）

### 安装和运行

#### 使用 Makefile（推荐）

```bash
# 克隆项目
git clone https://github.com/xdfnet/iMoni.git
cd iMoni

# 完整构建（包含版本号递增）
make build

# 固定版本构建
make build-fixed

# 查看所有可用命令
make help
```

#### 使用 Xcode

```bash
# 打开项目
open iMoni.xcodeproj

# 选择目标设备（macOS）
# 点击构建按钮或使用快捷键 Cmd+B
```

### 使用说明



1.  **全新应用图标**：iMoni 采用了全新的简洁现代图标设计，更容易识别。

1.  iMoni 启动后会在菜单栏显示图标

2.  点击图标查看监控菜单

3.  选择 "View" → "Service" 监控 AI 服务延迟

4.  选择 "View" → "Network" 监控网络流量

5.  通过 "Rate" 菜单调整监控频率（0.5s、1s、2s、5s）

6.  从分类菜单中选择不同的服务进行监控

7.  状态指示器显示连接状态（✓ 连接成功 / ⚠️ 连接失败）

## 项目结构

```text
iMoni/
├── iMoni/                    # 主要源代码
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

## 技术架构

### 设计模式

- **分层架构**：清晰的功能分层和职责分离
- **代理模式**：监控结果的回调通知（MonitorLatencyDelegate, MonitorNetworkDelegate）
- **观察者模式**：状态变化的实时更新
- **模板方法模式**：BaseMonitor 定义监控流程，子类实现具体逻辑
- **单例模式**：ServiceManager、ConfigurationManager 的全局访问
- **策略模式**：不同监控策略（延迟监控 vs 网络监控）

### 核心技术

- **Swift 5.0**：现代化的 Swift 语言特性
- **Cocoa**：传统的 macOS 应用框架
- **Network.framework**：高性能 TCP 连接建立和延迟测量
- **sysctl**：系统级网络统计信息获取
- **GCD**：异步任务和线程管理
- **NSLock**：线程安全的状态管理
- **UserDefaults**：用户配置持久化

### 架构优势

- **模块化设计**：每个组件职责单一，易于维护和扩展
- **线程安全**：使用 NSLock 和专用队列确保多线程环境稳定性
- **资源管理**：完善的资源清理机制，防止内存泄漏
- **用户体验**：简化状态管理，提供直观的界面反馈
- **代码质量**：统一的工具函数，减少重复代码，提高可维护性

## 开发指南

### 代码规范

- 遵循 Swift API Design Guidelines
- 使用统一的注释风格和 MARK 分组
- 支持中文注释，便于理解
- 完整的错误处理和日志记录
- 使用 `Utilities` 工具库统一常用功能

### 工具函数库

`Utilities.swift` 提供了丰富的工具函数：

- **格式化工具**：`formatLatency`, `formatSpeed`, `formatInterval`
- **时间工具**：`currentTimestamp`, `timeDifference`
- **线程安全工具**：`safeMainQueueCallback`
- **数值工具**：`safeInt`, `clamp`, `validateServiceEndpoint`
- **性能工具**：`measureExecutionTime`
- **调试工具**：`debugPrint`, `printPerformanceStats`

### 构建系统

```bash
make help              # 查看所有可用命令
make quality-check     # 运行代码质量检查
make clean             # 清理构建文件
make test              # 运行测试
```

### 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交代码变更
4. 创建 Pull Request

## 版本历史

- v1.22 (2025-11-21): 新增 OpenAI 服务监控；新增延迟高亮功能，优化视觉反馈
- v1.18 (2025-11-19): 修复网络监控 Bug，增加上传速度测量
- v1.17 (2025-10-11): 项目重命名为 iMoni，修复 Makefile 版本更新功能
- v1.11 (2025-09-01): 服务分类优化，添加 IDE Services 支持
- v1.10 (2025-08-31): 性能优化和 bug 修复
- v1.09 (2025-08-30): 网络监控稳定性改进
- v1.08 (2025-08-29): 用户界面优化和体验改进
- v1.07 (2025-01-13): 代码结构优化、工具函数统一、终端配置优化
- v1.06 (2025-01-13): 简化状态管理、状态指示器、配置管理
- v1.05 (2025-01-13): 代码质量检查、注释规范
- v1.04 (2025-01-13): 基础监控类、网络监控、服务管理
- v1.03 (2025-01-13): 延迟监控、菜单栏控制器
- v1.02 (2025-01-12): 应用入口、基础架构
- v1.01 (2025-01-12): 项目初始化、构建工具
- v1.00 (2025-01-12): 初始版本发布

## 文档

- [架构文档](Docs/ARCHITECTURE.md) - 系统架构设计
- [开发指南](Docs/DEVELOPMENT.md) - 开发者文档
- [API 参考](Docs/API_REFERENCE.md) - 完整的 API 文档
- [功能特性](Docs/FEATURES.md) - 详细功能说明
- [注释规范](Docs/COMMENT_STANDARDS.md) - 代码注释标准
- [更新日志](Docs/CHANGELOG.md) - 版本变更记录

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 联系方式

- 项目主页：<https://github.com/xdfnet/iMoni>
- 问题反馈：提交 GitHub Issue
- 功能建议：参与项目讨论

## 致谢

感谢所有为这个项目做出贡献的开发者和用户！

---

iMoni - 让 AI 服务监控变得简单高效

---

Built with ❤️ using Swift and SwiftUI

© 2025 iMoni App
