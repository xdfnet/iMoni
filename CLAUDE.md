# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

iMoni 是一个 macOS 菜单栏应用，用于实时监控 AI 服务的网络延迟和系统网络流量。采用 Swift 5.0 + AppKit 开发。只有 5 个源文件，极致精简。

## 常用命令

```bash
make debug        # 构建并运行 Debug
make install      # 构建并安装 Release 到 /Applications
make package      # 打包 Release 为 zip
make push MSG=""  # 完整发布：构建→安装→打包→提交→推送→GitHub Release
make clean        # 清理构建文件
make help         # 查看所有命令
```

## 源文件（5 个）

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| `App.swift` | ~30 | 应用入口，`@main`，睡眠/唤醒事件转发 |
| `Core.swift` | ~80 | 类型定义（ServiceEndpoint, ConnectionStatus, DisplayMode），工具函数（formatLatency, formatSpeed, mainQueue） |
| `MenuBarController.swift` | ~200 | 菜单栏控制器，NSStatusItem 管理，颜色/视图切换，双行 NSImage 渲染 |
| `MonitorLatency.swift` | ~120 | TCP 延迟监控，N 个实例可同时监控多个服务 |
| `MonitorNetwork.swift` | ~130 | 网络流量监控，上下行双方向读取 |

## 核心功能

### 显示模式 (View 菜单)

- **Service**：双行显示 OpenAI / DeepSeek 的 TCP 连接延迟
- **Network**：双行显示上行↑ / 下行↓ 网络速度

### 菜单栏渲染

- 使用 `NSStatusItem.button.image` 渲染双行文本为 NSImage
- `NSStatusItem.menu` + `NSMenuDelegate` 动态构建菜单
- 系统原生处理菜单位置、宽度适配

### 网络流量读取

- `getifaddrs()` 遍历非 loopback 接口
- 同时读取 `ifi_obytes`（上行）和 `ifi_ibytes`（下行）
- 差值法计算实时速度，按链路速率 `ifi_baudrate` 动态计算毛刺阈值
- 所有接口流量累加

### 延迟监控

- `NWConnection` TCP 连接测量建连时间
- 支持多实例同时监控不同服务
- 超时保护（0.5s），防重叠（isPinging 守卫）

### 服务端点

- DeepSeek (api.deepseek.com)
- OpenAI (api.openai.com)

### 配置持久化

- `UserDefaults`：`displayMode`（当前显示模式）

## 架构特点

- **代理模式**：`MonitorLatencyDelegate`, `MonitorNetworkDelegate`
- **安全沙盒**：启用 `com.apple.security.app-sandbox`
- **线程**：各监控器独立 serial queue，UI 更新统一 `mainQueue()`
- **无外部依赖**：纯 Apple SDK（Foundation, Network, Cocoa）

## 注意事项

1. 菜单栏渲染走 `NSStatusItem.button.image`，修改显示需更新 `renderImage()` 方法
2. 增加新服务只需在 `Core.swift` 的 `services` 数组追加，并对应增加 `MonitorLatency` 实例
3. 沙盒限制不能调外部进程（如 `/sbin/ping`），延迟监控必须用 `NWConnection`
4. `NSMenuDelegate.menuWillOpen` 每次菜单打开前重建内容，保证状态实时更新
