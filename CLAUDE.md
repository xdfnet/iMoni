# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

iMoni 是一个 macOS 菜单栏系统监控工具，实时监控网络流量、内存占用和 CPU/GPU 使用率。采用 Swift + AppKit 开发。**7 个源文件，零外部依赖。**

## 常用命令

```bash
make debug        # 构建并运行 Debug
make install      # 构建并安装 Release 到 /Applications
make package      # 打包 Release 为 zip
make push MSG=""  # 完整发布：构建→安装→打包→提交→推送→GitHub Release
make clean        # 清理构建文件
make help         # 查看所有命令
```

## 源文件（7 个）

| 文件 | 行数 | 职责 |
| --- | --- | --- |
| `App.swift` | ~30 | 应用入口，`@main`，睡眠/唤醒事件转发 |
| `Core.swift` | ~55 | 类型定义（DisplayMode），工具函数（formatSpeed, formatMemoryGB, formatCPUPercent, mainQueue） |
| `MenuBarController.swift` | ~240 | 菜单栏控制器，NSStatusItem 管理，5 个 Delegate 实现，双行 NSImage 渲染 |
| `MonitorNetwork.swift` | ~130 | 网络流量监控，getifaddrs() 差值法，动态毛刺阈值 |
| `MonitorMemory.swift` | ~100 | 物理内存监控，host_statistics64(HOST_VM_INFO64) |
| `MonitorCPU.swift` | ~95 | CPU 占用率，host_processor_info() 逐核采集 |
| `MonitorGPU.swift` | ~100 | GPU 占用率，IOKit IOAccelerator Device Utilization % |

## 显示模式 (View 菜单)

- **Network**：双行显示上行 / 下行网络速度
- **Memory**：双行显示 RAM 占用 GB + 百分比
- **CPU/GPU**：双行显示 CPU / GPU 使用率

## 数据采集

### 网络流量

- `getifaddrs()` 遍历非 loopback 接口
- 同时读取 `ifi_obytes`（上行）和 `ifi_ibytes`（下行）
- 差值法计算实时速度，按链路速率 `ifi_baudrate` 动态计算毛刺阈值
- 所有接口流量累加

### 内存

- `host_statistics64(HOST_VM_INFO64)` 获取 `vm_statistics64_data_t`
- 公式：`used = active + inactive + speculative + wired + compressed - purgeable - external`
- `host_info(HOST_BASIC_INFO)` 获取 `max_mem` 物理内存总量

### CPU

- `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 逐核采集 ticks
- 与前一次采样做差值，计算 `inUse / total` 比率
- `vm_deallocate` 释放每轮采集的内存

### GPU

- `IOServiceGetMatchingServices("IOAccelerator")` 查询显卡
- `IORegistryEntryCreateCFProperties` 读取 `PerformanceStatistics` 字典
- key: `"Device Utilization %"`

### 定时器

所有监控器使用 `DispatchSourceTimer`（替代 `Timer`）：

```swift
let t = DispatchSource.makeTimerSource(queue: queue)
t.schedule(deadline: .now(), repeating: .milliseconds(ms), leeway: .milliseconds(100))
t.setEventHandler { [weak self] in self?.update() }
t.activate()
```

## 配置持久化

- `UserDefaults`：`displayMode`（当前显示模式）

## 架构特点

- **代理模式**：`MonitorNetworkDelegate`, `MonitorMemoryDelegate`, `MonitorCPUDelegate`, `MonitorGPUDelegate`
- **线程**：各监控器独立 serial queue，UI 更新统一 `mainQueue()`
- **无外部依赖**：纯 Apple SDK（Foundation, Network, Cocoa, IOKit）
- **模式切换**：切模式自动停掉不需要的监控器，不浪费 CPU

## 注意事项

1. 菜单栏渲染走 `NSStatusItem.button.image`，修改显示需更新 `renderImage()` 方法
2. `NSMenuDelegate.menuWillOpen` 每次菜单打开前重建内容，保证状态实时更新
3. 内存单位统一用 **二进制**（1024³），不要用十进制 GB（10⁹），否则 host_info 的总字节数对不上
4. CPU 的 `host_processor_info` 会分配内存，每次新采集前记得 `vm_deallocate` 旧指针
5. MonitorConstants 和 mainQueue 定义在 Core.swift，在同一 module 内直接引用
