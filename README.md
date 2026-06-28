# iMoni — macOS 菜单栏系统监控

[![Version](https://img.shields.io/github/v/release/xdfnet/iMoni?style=flat-square)](https://github.com/xdfnet/iMoni/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-15.0+-green.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 简介

iMoni 是一个轻量级 macOS 菜单栏系统监控工具，实时监控网络流量、内存占用、CPU/GPU 使用率和网络延迟稳定性。**8 个源文件，零外部依赖。**

## 特性

### 4 种显示模式

| 模式 | 内容 | 技术 |
|------|------|------|
| **Network** | 网络上行 / 下行实时速率 | `getifaddrs()` 字节差值 |
| **Memory** | 物理内存占用 GB + 百分比 | `host_statistics64` + `host_info` |
| **CPU/GPU** | CPU / GPU 使用率百分比 | `host_processor_info` + IOKit `IOAccelerator` |
| **Latency** | 网络延迟 / 丢包 + 抖动 | HEAD `www.gstatic.com/generate_204` 长连接 |

### 特点

- **菜单栏集成**：双行文本渲染，不占桌面空间
- **模式切换**：View 菜单一键切换，自动启停对应监控器
- **配置持久化**：`UserDefaults` 保存当前显示模式
- **休眠唤醒**：监听系统睡眠/唤醒事件，自动暂停恢复

## 环境要求

- macOS 15.0+
- Xcode 15.0+
- Swift 5.0+

## 安装

```bash
git clone https://github.com/xdfnet/iMoni.git
cd iMoni
make install   # 构建 Release 并安装到 /Applications
```

## 使用

启动后出现在菜单栏，点击弹出菜单：

- **View** → 切换 4 种显示模式
- **Quit** → 退出应用

## 项目结构

```text
iMoni/
├── iMoni/
│   ├── App.swift               # 应用入口（~35行）
│   ├── Core.swift              # 类型定义、格式化、工具函数（~70行）
│   ├── MenuBarController.swift # 菜单栏 UI + 监控编排（~260行）
│   ├── MonitorNetwork.swift    # 网络流量监控（~140行）
│   ├── MonitorMemory.swift     # 物理内存监控（~95行）
│   ├── MonitorCPU.swift        # CPU 占用率监控（~105行）
│   ├── MonitorGPU.swift        # GPU 占用率监控（~85行）
│   └── MonitorStability.swift  # 网络稳定性监控（~160行）
├── Assets.xcassets/
└── Makefile
```

## 技术架构

### 数据采集

| 指标 | API | 来源 |
|------|-----|------|
| 网络流量 | `getifaddrs()` → `ifi_obytes/ifi_ibytes` | POSIX |
| 物理内存 | `host_statistics64(HOST_VM_INFO64)` + `host_info(HOST_BASIC_INFO)` | Mach API |
| CPU 使用率 | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 逐核采集 | Mach API |
| GPU 使用率 | `IOServiceGetMatchingServices("IOAccelerator")` | IOKit |
| 网络稳定性 | HEAD `www.gstatic.com/generate_204` 长连接 | NWConnection |

### 调度

所有监控器使用 `DispatchSourceTimer` 定时触发，1 秒间隔，200ms leeway。切换模式时自动启停，不同模式互不干扰。

### 渲染

`NSStatusItem.button.image` 双行 `NSImage` 手绘文本，9pt monospaced 字体。

## 构建命令

```bash
make debug     # Debug 构建并启动
make install   # Release 构建并安装到 /Applications
make package   # 打包为 zip
make push      # 构建→安装→打包→提交→推送→GitHub Release
make clean     # 清理
```

## 版本历史

- **v1.6.0** (2026-06-28): 新增 Latency 模式，TCP ping www.gstatic.com 实时监控网络延迟/抖动/丢包率
- **v1.5.0** (2026-06-22): 移除 Latency 模式，精简至 7 源文件；统一数据模式；代码规范优化
- **v1.3.2** (2026-06-11): 统一采集方式对齐 Stats；修复内存单位混用；全部改用 DispatchSourceTimer
- **v1.3.1** (2026-06-10): 新增 Memory/CPU/GPU 监控；菜单重构
- [历史版本](https://github.com/xdfnet/iMoni/releases)

## 许可证

MIT License
