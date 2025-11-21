//
//  MenuBarController.swift
//  Moni
//
//  Created by Moni Team
//  Copyright © 2025 Moni App. All rights reserved.
//
//  菜单栏控制器：负责状态栏文本展示与菜单交互
//
//  功能说明：
//  - 组合并展示当前模式下的状态文本（服务延迟 / 网络速度）
//  - 构建并响应菜单项（显示模式、服务选择、版本/构建信息、退出）
//  - 协调 MonitorLatency 与 MonitorNetwork 的启停
//
import Cocoa
import SwiftUI

// MARK: - 显示模式枚举
enum DisplayMode: String, CaseIterable {
    case serviceLatency = "Service"
    case networkSpeed = "Network"
}

// MARK: - 菜单栏控制器
class MenuBarController: NSObject, MonitorLatencyDelegate, MonitorNetworkDelegate {
    
    // MARK: - 属性
    
    /// UI 组件
    private var statusBarItem: NSStatusItem?
    
    /// 监控服务
    private let monitor = MonitorLatency(queueLabel: MonitorConstants.latencyQueueLabel, interval: MonitorConstants.defaultLatencyInterval)
    private let networkStats = MonitorNetwork(queueLabel: MonitorConstants.networkQueueLabel, interval: MonitorConstants.defaultNetworkInterval)
    
    /// 状态数据
    private var currentEndpoint: ServiceEndpoint?
    private var rawLatency: TimeInterval = 0.0
    private var currentDownloadSpeed: String = AppConstants.defaultValue
    private var currentUploadSpeed: String = AppConstants.defaultValue
    
    /// 状态指示器
    private var connectionStatus: ConnectionStatus = .disconnected
    private var isHealthy: Bool = true
    
    /// 当前展示模式（切换时联动启停对应监控）
    private var currentDisplayMode: DisplayMode = .serviceLatency {
        didSet {
            saveSettings()
            updateCombinedDisplay()
            updateMonitoringState()
        }
    }
    
    /// 当前监控间隔（用户可配置）
    private var currentMonitoringInterval: TimeInterval = MonitorConstants.defaultUserInterval {
        didSet {
            saveSettings()
            updateMonitoringState()
        }
    }
    
    // MARK: - 初始化
    
    override init() {
        super.init()
        loadSettings()
        setupStatusBar()
        setupMonitor()
        setupDefaultMonitoring()
        updateCombinedDisplay()
    }
    
    // MARK: - 生命周期管理
    
    func cleanup() {
        monitor.stopMonitoring()
        networkStats.stopMonitoring()
        statusBarItem = nil
    }

    /// 系统即将睡眠：暂停监控并移除状态栏项，防止唤醒后按钮丢失/无响应
    func suspend() {
        monitor.stopMonitoring()
        networkStats.stopMonitoring()
        statusBarItem = nil
    }

    /// 系统唤醒后：重建状态栏项并恢复监控
    func resumeAfterWake() {
        // 重新创建状态栏按钮
        if statusBarItem == nil {
            setupStatusBar()
        }
        // 恢复监控状态
        updateMonitoringState()
        updateCombinedDisplay()
    }
    
    // MARK: - 私有方法
    
    /// 初始化状态栏按钮（等宽字体避免数值跳动）
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }
    
    /// 绑定代理与基础参数
    private func setupMonitor() {
        monitor.delegate = self
        monitor.updateInterval(currentMonitoringInterval)
        networkStats.delegate = self
    }
    
    /// 设置默认监控状态
    private func setupDefaultMonitoring() {
        if currentDisplayMode == .serviceLatency {
            // 优先使用已保存的服务，如果没有则默认选择 Claude
            if let endpoint = currentEndpoint {
                Utilities.debugPrint("使用已保存的服务: \(endpoint.name)")
                switchToEndpoint(endpoint)
            } else if let claudeEndpoint = ServiceManager.shared.endpoints.first(where: { $0.name == "Claude" }) {
                Utilities.debugPrint("使用默认服务: Claude")
                currentEndpoint = claudeEndpoint
                switchToEndpoint(claudeEndpoint)
            } else if let firstEndpoint = ServiceManager.shared.endpoints.first {
                Utilities.debugPrint("使用第一个可用服务: \(firstEndpoint.name)")
                currentEndpoint = firstEndpoint
                switchToEndpoint(firstEndpoint)
            } else {
                Utilities.debugPrint("警告: 没有可用的服务端点")
            }
        } else {
            networkStats.startMonitoring(interval: currentMonitoringInterval)
        }
    }
    
    /// 更新监控状态
    private func updateMonitoringState() {
        if currentDisplayMode == .serviceLatency {
            if let endpoint = currentEndpoint {
                monitor.startMonitoring(endpoint)
            }
            networkStats.stopMonitoring()
        } else {
            monitor.stopMonitoring()
            networkStats.startMonitoring(interval: currentMonitoringInterval)
        }
    }
    
    /// 点击状态栏按钮时动态创建菜单（避免菜单粘连）
    @objc private func statusBarButtonClicked() {
        statusBarItem?.menu = createMenu()
        statusBarItem?.button?.performClick(nil)
        statusBarItem?.menu = nil
    }
    
    /// 构建主菜单
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // 显示模式选择
        menu.addItem(createDisplayModeMenu())
        menu.addItem(NSMenuItem.separator())
        
        // 直接加入三个服务分类
        for category in ServiceManager.shared.categories {
            menu.addItem(createServiceCategoryMenu(for: category))
        }
        menu.addItem(NSMenuItem.separator())
        
        // 监控间隔设置
        menu.addItem(createMonitoringIntervalMenu())
        menu.addItem(NSMenuItem.separator())
        
        // About 信息
        menu.addItem(createAboutMenu())
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        menu.addItem(createQuitMenu())
        
        return menu
    }
    
    /// 创建显示模式菜单
    private func createDisplayModeMenu() -> NSMenuItem {
        let displayModeItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let displayModeSubmenu = NSMenu()
        
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(
                title: mode.rawValue,
                action: #selector(displayModeSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (currentDisplayMode == mode) ? .on : .off
            displayModeSubmenu.addItem(item)
        }
        
        displayModeItem.submenu = displayModeSubmenu
        return displayModeItem
    }
    
    /// 创建监控间隔设置菜单
    private func createMonitoringIntervalMenu() -> NSMenuItem {
        let intervalItem = NSMenuItem(title: "Rate", action: nil, keyEquivalent: "")
        let intervalSubmenu = NSMenu()
        
        // 使用 MonitorConstants 中定义的可用间隔
        for interval in MonitorConstants.availableIntervals {
            let title: String
            if interval < 1.0 {
                title = "\(interval)s"  // 0.5s 而不是 500ms
            } else if interval == 1.0 {
                title = "1s"
            } else {
                title = "\(Int(interval))s"
            }
            
            let item = NSMenuItem(
                title: title,
                action: #selector(monitoringIntervalSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = interval
            item.state = (currentMonitoringInterval == interval) ? .on : .off
            intervalSubmenu.addItem(item)
        }
        
        intervalItem.submenu = intervalSubmenu
        return intervalItem
    }
    
    /// 创建服务选择菜单
    private func createServiceCategoryMenu(for category: ServiceCategory) -> NSMenuItem {
        let categoryItem = NSMenuItem(title: category.displayName, action: nil, keyEquivalent: "")
        let categorySubmenu = NSMenu()
        
        // 为该类别添加服务
        let endpoints = ServiceManager.shared.getEndpoints(for: category)
        for endpoint in endpoints {
            let item = NSMenuItem(
                title: endpoint.name,
                action: #selector(serviceSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = endpoint
            item.state = (endpoint.name == currentEndpoint?.name) ? .on : .off
            categorySubmenu.addItem(item)
        }
        
        categoryItem.submenu = categorySubmenu
        return categoryItem
    }
    
    /// 创建 About 菜单
    private func createAboutMenu() -> NSMenuItem {
        let aboutItem = NSMenuItem(title: "About", action: nil, keyEquivalent: "")
        let aboutSubmenu = NSMenu()
        
        // 版本信息
        let versionItem = NSMenuItem(
            title: "Version: \(AppConstants.Version.current)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        aboutSubmenu.addItem(versionItem)
        
        // 构建信息
        let buildItem = NSMenuItem(
            title: "Build: \(AppConstants.Version.build)",
            action: nil,
            keyEquivalent: ""
        )
        buildItem.isEnabled = false
        aboutSubmenu.addItem(buildItem)
        
        // 分隔线
        aboutSubmenu.addItem(NSMenuItem.separator())
        
        // 版权信息
        let copyrightItem = NSMenuItem(
            title: "© 2025 Moni App",
            action: nil,
            keyEquivalent: ""
        )
        copyrightItem.isEnabled = false
        aboutSubmenu.addItem(copyrightItem)
        
        aboutItem.submenu = aboutSubmenu
        return aboutItem
    }
    
    /// 创建退出菜单
    private func createQuitMenu() -> NSMenuItem {
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        return quitItem
    }
    
    // MARK: - 菜单事件处理
    
    @objc private func displayModeSelected(_ sender: NSMenuItem) {
        guard let modeString = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: modeString) else { return }
        currentDisplayMode = mode
    }
    
    @objc private func monitoringIntervalSelected(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else { return }
        currentMonitoringInterval = interval
    }
    
    @objc private func serviceSelected(_ sender: NSMenuItem) {
        guard let endpoint = sender.representedObject as? ServiceEndpoint else { return }
        
        // 选择服务时自动切换到Service显示模式
        if currentDisplayMode != .serviceLatency {
            currentDisplayMode = .serviceLatency
        }
        
        switchToEndpoint(endpoint)
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - 设置管理
    
    /// 从用户偏好读取当前模式和服务
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // 加载显示模式
        if let rawValue = defaults.string(forKey: "currentDisplayMode"),
           let mode = DisplayMode(rawValue: rawValue) {
            currentDisplayMode = mode
        }
        
        // 加载监控间隔
        if let interval = defaults.object(forKey: "currentMonitoringInterval") as? TimeInterval {
            currentMonitoringInterval = interval
        }
        
        // 加载上次选择的服务
        if let savedServiceName = defaults.string(forKey: "lastSelectedService") {
            if let savedEndpoint = ServiceManager.shared.endpoints.first(where: { $0.name == savedServiceName }) {
                currentEndpoint = savedEndpoint
            }
        }
    }
    
    /// 将当前模式和服务写入用户偏好
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(currentDisplayMode.rawValue, forKey: "currentDisplayMode")
        defaults.set(currentMonitoringInterval, forKey: "currentMonitoringInterval")
        
        if let endpoint = currentEndpoint {
            defaults.set(endpoint.name, forKey: "lastSelectedService")
        }
    }
    
    // MARK: - 服务管理
    
    /// 切换服务端点并立即开始延迟监控
    private func switchToEndpoint(_ endpoint: ServiceEndpoint) {
        currentEndpoint = endpoint
        monitor.startMonitoring(endpoint)
        updateCombinedDisplay()
        saveSettings()  // 保存服务选择
    }
    
    // MARK: - 显示更新
    
    /// 汇总当前需要显示的文本并更新到状态栏
    private func updateCombinedDisplay() {
        let attributedDisplayText = createAttributedDisplayText()
        let statusIcon = createStatusIcon()
        
        Utilities.safeMainQueueCallback { [weak self] in
            guard let self = self else { return }
            
            if let button = self.statusBarItem?.button {
                button.attributedTitle = attributedDisplayText
                button.image = statusIcon
                
                // 设置工具提示
                button.toolTip = self.createTooltip()
            }
        }
    }
    
    /// 创建状态图标
    private func createStatusIcon() -> NSImage? {
        if connectionStatus == .connected {
            // 连接成功显示检查图标
            return NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Connected")
        } else {
            // 连接失败显示警告图标
            return NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Disconnected")
        }
    }
    
    /// 创建工具提示
    private func createTooltip() -> String {
        var tooltip = "Moni - Network Monitor\n"
        
        switch currentDisplayMode {
        case .serviceLatency:
            if let endpoint = currentEndpoint {
                tooltip += "Service: \(endpoint.name)\n"
                tooltip += "Host: \(endpoint.host):\(endpoint.port)\n"
                tooltip += "Latency: \(Utilities.formatLatency(rawLatency))\n"
            } else {
                tooltip += "No service selected\n"
            }
        case .networkSpeed:
            tooltip += "Download Speed: \(currentDownloadSpeed)\n"
            tooltip += "Upload Speed: \(currentUploadSpeed)\n"
        }
        
        tooltip += "Update Rate: \(Utilities.formatInterval(currentMonitoringInterval))\n"
        
        if connectionStatus == .disconnected {
            tooltip += "Status: Disconnected"
        } else {
            tooltip += "Status: Connected"
        }
        
        return tooltip
    }
    
    /// 创建带属性的显示文本
    private func createAttributedDisplayText() -> NSAttributedString {
        switch currentDisplayMode {
        case .serviceLatency:
            let serviceName = currentEndpoint?.name ?? AppConstants.defaultValue
            
            if connectionStatus != .connected {
                return NSAttributedString(string: "\(serviceName): \(AppConstants.defaultValue)")
            }
            
            // 根据延迟确定颜色
            let latencyColor: NSColor
            if rawLatency > 500 {
                latencyColor = .systemRed
            } else if rawLatency > 200 {
                latencyColor = .systemOrange
            } else {
                latencyColor = .labelColor
            }
            
            let latencyString = Utilities.formatLatency(rawLatency)
            let fullString = "\(serviceName): \(latencyString)"
            let attributedString = NSMutableAttributedString(string: fullString)
            
            // 只对延迟部分应用颜色
            let range = (fullString as NSString).range(of: latencyString)
            attributedString.addAttribute(.foregroundColor, value: latencyColor, range: range)
            
            return attributedString
            
        case .networkSpeed:
            return NSAttributedString(string: "↓\(currentDownloadSpeed) ↑\(currentUploadSpeed)")
        }
    }
    

    
    // MARK: - MonitorLatencyDelegate
    
    /// 延迟更新回调（毫秒，0 位小数）
    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint) {
        rawLatency = latency
        connectionStatus = .connected
        isHealthy = true
        updateCombinedDisplay()
    }
    
    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint) {
        rawLatency = 0.0
        connectionStatus = status
        isHealthy = false
        
        updateCombinedDisplay()
    }
    
    // MARK: - MonitorNetworkDelegate
    
    /// 上/下行网速更新（单位 MB/s，3 位小数）
    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double, uploadSpeed: Double) {
        currentDownloadSpeed = Utilities.formatSpeed(downloadSpeed)
        currentUploadSpeed = Utilities.formatSpeed(uploadSpeed)
        connectionStatus = .connected
        isHealthy = true
        updateCombinedDisplay()
    }
    
    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus) {
        currentDownloadSpeed = AppConstants.defaultValue
        currentUploadSpeed = AppConstants.defaultValue
        connectionStatus = status
        isHealthy = false
        
        updateCombinedDisplay()
    }
}