# 更新日志

所有重要的更改都将记录在此文件中。

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范。

## [1.3.2] - 2026-06-11

### 🔧 统一采集方式

对齐 [Stats](https://github.com/exelban/stats) 的数据采集方式：

- **CPU**：改用 `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 逐核采集 ticks，汇总算总使用率
- **内存**：改用 `host_statistics64(HOST_VM_INFO64)` + `host_info(HOST_BASIC_INFO)`，公式 `active + inactive + speculative + wired + compressed - purgeable - external`
- **定时器**：全部从 `Timer`（RunLoop）迁移至 `DispatchSourceTimer`（dispatch queue）
- **修复**：内存单位混用 bug（十进制 GB ↔ 二进制 GB 不一致导致总量显示 52 而不是 48）

### 文件变更

- 新增：`MonitorCPU.swift`, `MonitorGPU.swift`, `MonitorMemory.swift`
- 修改：全部 5 个监控器重写定时器逻辑

## [1.3.1] - 2026-06-10

### 🚀 新增功能

- **Memory 模式**：物理内存占用显示 `RAM x GB / PCT x%`
- **CPU/GPU 模式**：实时 CPU + GPU 使用率百分比
- 菜单栏 View 菜单从 2 项扩展至 4 项
- 统一英文 UI 标签，移除版本号显示

### 技术实现

- 内存：`host_statistics(HOST_VM_INFO)` + `getpagesize()` + `ProcessInfo.physicalMemory`
- CPU：`host_statistics(HOST_CPU_LOAD_INFO)` 两次 tick 差值
- GPU：IOKit `IOAccelerator` 读取 `Device Utilization %`

## [1.3.0] - 2026-06-10

### 🔨 全面重构

- 从头重写项目，文件数从 10 个缩减至 5 个（后扩展至 8 个）
- 删除 BaseMonitor / ServiceManager / ConfigurationManager 等冗余抽象层
- 删除 AI 服务列表（从 7 个缩减为 DeepSeek + OpenAI 双服务）
- 删除全部测试文件、文档目录

### ✨ 新功能

- **Service 模式**：双服务（DeepSeek / OpenAI）TCP 建连时间显示
- **Network 模式**：上行↑ / 下行↓ 实时网络速率
- 原生 NSMenu 菜单栏，View 菜单切换显示模式
- 睡眠/唤醒事件监听
- UserDefaults 配置持久化

## [1.28] - 2026-05-02

_(历史版本，详情见 [GitHub Releases](https://github.com/xdfnet/iMoni/releases))_

## [1.19] - 2025-11-19

### 🐛 修复问题
- 修复了网络监控模块的 Bug，该 Bug 导致上传速度始终显示为 0。

### 🚀 新增功能
- 网络监控模块现在支持精确测量和显示上传速度（MB/s），与下载速度一同实时呈现。

## [1.11] - 2025-01-13

### 🚀 新增功能
- 性能监控优化，实时显示 CPU 和内存使用情况
- 新增自动重连机制，提高服务稳定性
- 支持更多 AI 服务端点

### 🔧 优化改进
- **性能优化**：显著降低 CPU 占用率，从平均 5% 降至 2%
- **内存管理**：修复长时间运行可能出现的内存泄漏问题
- **代码重构**：统一使用 Utilities 工具函数库，提高代码复用性
- **线程安全**：优化多线程回调机制，确保 UI 更新在主线程执行

### 🐛 修复问题
- 修复系统休眠唤醒后监控停止的问题
- 修复网络切换时连接状态显示错误
- 修复某些情况下菜单栏图标消失的问题

### 📚 文档更新
- 更新 README.md，添加详细的使用说明
- 添加架构设计文档
- 完善代码注释，支持中英文双语

## [1.10] - 2025-01-13

### 🎨 界面优化
- 重新设计菜单栏布局，更加直观
- 优化状态指示器显示效果
- 添加深色模式支持

### 🚀 用户体验
- 简化配置流程
- 添加快捷键支持
- 优化响应速度

## [1.09] - 2025-01-13

### 🌟 新增服务
- 支持 Claude API 监控
- 支持 Gemini API 监控
- 支持 DeepSeek API 监控
- 添加 Docker Hub 监控
- 添加 NPM Registry 监控

### 🔧 配置优化
- 支持自定义监控间隔
- 添加服务分组管理
- 优化默认配置

## [1.08] - 2025-01-13

### 🐛 Bug 修复
- 修复高 DPI 显示器下的显示问题
- 修复某些网络环境下的连接问题
- 修复配置文件读写权限问题

### 🚀 性能调优
- 优化网络请求处理
- 减少不必要的 UI 刷新
- 改进缓存机制

## [1.07] - 2025-01-13

### 🔨 代码结构优化
- 删除重复和未使用的函数
- 统一工具函数库 (Utilities.swift)
- 实现 BaseMonitor 基类
- 优化文件组织结构

### 🔧 技术改进
- 线程安全优化：使用 safeMainQueueCallback
- 环境变量继承：支持 zsh 和 bash
- Python 路径优化：自动识别 Homebrew Python
- 终端配置统一：Cursor 和 VSCode 配置

## [1.06] - 2025-01-13

### ✨ 核心功能
- 简化状态管理机制
- 添加状态指示器（✓ 成功 / ⚠️ 失败）
- 实现配置管理器 (ConfigurationManager)
- 支持用户偏好设置持久化

## [1.05] - 2025-01-13

### 📋 代码质量
- 添加代码质量检查脚本
- 完善注释规范
- 支持中英文双语注释
- 添加 MARK 分组标记

## [1.04] - 2025-01-13

### 🏗️ 架构设计
- 实现基础监控类 (BaseMonitor)
- 添加网络流量监控 (MonitorNetwork)
- 创建服务管理器 (ServiceManager)
- 定义共享类型 (SharedTypes)

## [1.03] - 2025-01-13

### 📡 监控功能
- 实现 TCP 延迟监控 (MonitorLatency)
- 创建菜单栏控制器 (MenuBarController)
- 支持多服务切换
- 添加监控频率调整

## [1.02] - 2025-01-12

### 🎯 应用基础
- 创建应用入口 (App.swift)
- 搭建基础架构
- 配置项目结构
- 设置开发环境

## [1.01] - 2025-01-12

### 🛠️ 项目初始化
- 初始化 Xcode 项目
- 配置 Makefile 构建工具
- 设置 Git 仓库
- 创建基础目录结构

## [1.00] - 2025-01-12

### 🎉 初始版本
- 项目立项
- 确定技术栈：Swift 5.0+, macOS 15.0+
- 制定开发计划
- 创建项目文档

---

## 版本说明

### 版本号规则
- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 标签说明
- 🚀 新增功能
- 🔧 优化改进
- 🐛 修复问题
- 📚 文档更新
- 🎨 界面优化
- 🔨 代码重构
- 🏗️ 架构设计
- 📡 监控功能
- 🎯 核心功能
- 🛠️ 工具配置
- 📋 代码质量
- ✨ 特性改进
- 🌟 服务支持
- 🎉 重要里程碑

### 贡献者
- 主要开发者：xdfnet
- 特别感谢所有提供反馈和建议的用户

### 相关链接
- [项目主页](https://github.com/xdfnet/iMoni)
- [问题反馈](https://github.com/xdfnet/iMoni/issues)
- [下载发布版](https://github.com/xdfnet/iMoni/releases)