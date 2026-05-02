# iMoni - AI 服务延迟监控工具

[![Version](https://img.shields.io/github/v/release/xdfnet/iMoni?style=flat-square)](https://github.com/xdfnet/iMoni/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-15.0+-green.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 项目简介

iMoni 是一个轻量级的 macOS 菜单栏应用，专门用于实时监控 AI 服务的网络延迟和系统网络流量。通过优化的代码结构、统一的工具函数库和现代化的架构设计，为开发者提供可靠的网络监控体验。

## 主要特性

### 核心功能

- **AI 服务延迟监控**：实时测量各种 AI 服务的网络延迟（毫秒精度）
- **网络流量监控**：监控系统网络上/下行速度（MB/s，三位小数精度）
- **延迟高亮**：延迟超过阈值时以不同颜色显示，提供即时视觉警报
- **菜单栏集成**：轻量级设计，不占用桌面空间
- **可配置监控间隔**：支持 0.5s、1s、2s、5s 多种频率

### 最新功能 (v1.28)

- **极致精简**：源码从 10 个文件 1150 行精简至 5 个文件 550 行
- **移除冗余层**：删除 BaseMonitor 抽象基类、ServiceManager 单例、ConfigurationManager 单例
- **聚焦 AI 服务**：仅保留 7 个 AI 服务端点，删除 IDE/开发/网络分类
- **删除冗余代码**：删除测试、文档、脚本、速度平滑、导入导出配置等未使用功能

### 服务支持

- **OpenAI** (api.openai.com)
- **Claude** (api.anthropic.com)
- **Gemini** (generativelanguage.googleapis.com)
- **DeepSeek** (api.deepseek.com)
- **GLM** (open.bigmodel.cn)
- **Qwen** (dashscope.aliyuncs.com)
- **Kimi** (api.moonshot.cn)

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
│   ├── App.swift           # 应用入口（~35行）
│   ├── Core.swift          # 共享类型、服务列表、配置、格式化（~120行）
│   ├── MenuBarController.swift  # 菜单栏 UI 和编排（~200行）
│   ├── MonitorLatency.swift    # TCP 延迟监控（~80行）
│   └── MonitorNetwork.swift    # 系统网络流量监控（~100行）
├── Assets.xcassets/         # 应用资源
└── Makefile                 # 构建自动化脚本
```

## 技术架构

### 设计模式

- **代理模式**：监控结果的回调通知（MonitorLatencyDelegate, MonitorNetworkDelegate）
- **观察者模式**：状态变化的实时更新
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

### 工具函数

`Core.swift` 提供少量核心工具函数：

- **格式化**：`formatLatency()`, `formatSpeed()`
- **调度**：`mainQueue()`

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

- v1.28 (2026-05-02): **极致精简** — 源码从 10 文件 1150 行精简至 5 文件 550 行
- v1.22 (2025-11-21): 新增 OpenAI 服务监控；新增延迟高亮功能
- v1.18 (2025-11-19): 修复网络监控 Bug，增加上传速度测量
- v1.17 (2025-10-11): 项目重命名为 iMoni
- v1.11 (2025-09-01): 服务分类优化
- v1.07 (2025-01-13): 代码结构优化、工具函数统一
- v1.06 (2025-01-13): 简化状态管理、配置管理
- v1.05 (2025-01-13): 代码质量检查
- v1.04 (2025-01-13): 基础监控类、网络监控
- v1.03 (2025-01-13): 延迟监控、菜单栏控制器
- v1.02 (2025-01-12): 应用入口、基础架构
- v1.01 (2025-01-12): 项目初始化

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 联系方式

- 项目主页：<https://github.com/xdfnet/iMoni>
- 问题反馈：提交 GitHub Issue
