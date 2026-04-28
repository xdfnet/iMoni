import Cocoa
import SwiftUI

enum DisplayMode: String, CaseIterable {
    case serviceLatency = "Service"
    case networkSpeed = "Network"
}

class MenuBarController: NSObject, MonitorLatencyDelegate, MonitorNetworkDelegate {
    private var statusBarItem: NSStatusItem?

    private let latencyMonitor = MonitorLatency(queueLabel: MonitorConstants.latencyQueueLabel, interval: MonitorConstants.defaultLatencyInterval)
    private let networkMonitor = MonitorNetwork(queueLabel: MonitorConstants.networkQueueLabel, interval: MonitorConstants.defaultNetworkInterval)

    private var currentEndpoint: ServiceEndpoint?
    private var rawLatency: TimeInterval = 0.0
    private var currentDownloadSpeed: String = AppConstants.defaultValue
    private var currentUploadSpeed: String = AppConstants.defaultValue
    private var connectionStatus: ConnectionStatus = .disconnected

    private var currentDisplayMode: DisplayMode = .serviceLatency {
        didSet {
            saveSettings()
            updateCombinedDisplay()
            updateMonitoringState()
        }
    }

    private var currentMonitoringInterval: TimeInterval = MonitorConstants.defaultUserInterval {
        didSet {
            saveSettings()
            updateMonitoringState()
        }
    }

    override init() {
        super.init()
        loadSettings()
        setupStatusBar()
        setupMonitor()
        setupDefaultMonitoring()
        updateCombinedDisplay()
    }

    func cleanup() {
        latencyMonitor.stopMonitoring()
        networkMonitor.stopMonitoring()
        statusBarItem = nil
    }

    func suspend() {
        latencyMonitor.stopMonitoring()
        networkMonitor.stopMonitoring()
        statusBarItem = nil
    }

    func resumeAfterWake() {
        if statusBarItem == nil {
            setupStatusBar()
        }
        updateMonitoringState()
        updateCombinedDisplay()
    }

    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }

    private func setupMonitor() {
        latencyMonitor.delegate = self
        latencyMonitor.updateInterval(currentMonitoringInterval)
        networkMonitor.delegate = self
    }

    private func setupDefaultMonitoring() {
        if currentDisplayMode == .serviceLatency {
            if let endpoint = currentEndpoint {
                switchToEndpoint(endpoint)
            } else if let claudeEndpoint = ServiceManager.shared.endpoints.first(where: { $0.name == "Claude" }) {
                currentEndpoint = claudeEndpoint
                switchToEndpoint(claudeEndpoint)
            } else if let firstEndpoint = ServiceManager.shared.endpoints.first {
                currentEndpoint = firstEndpoint
                switchToEndpoint(firstEndpoint)
            }
        } else {
            networkMonitor.startMonitoring(interval: currentMonitoringInterval)
        }
    }

    private func updateMonitoringState() {
        if currentDisplayMode == .serviceLatency {
            if let endpoint = currentEndpoint {
                latencyMonitor.startMonitoring(endpoint)
            }
            networkMonitor.stopMonitoring()
        } else {
            latencyMonitor.stopMonitoring()
            networkMonitor.startMonitoring(interval: currentMonitoringInterval)
        }
    }

    @objc private func statusBarButtonClicked() {
        statusBarItem?.menu = createMenu()
        statusBarItem?.button?.performClick(nil)
        statusBarItem?.menu = nil
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(createDisplayModeMenu())
        menu.addItem(NSMenuItem.separator())
        for category in ServiceManager.shared.categories {
            menu.addItem(createServiceCategoryMenu(for: category))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createMonitoringIntervalMenu())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createAboutMenu())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createQuitMenu())
        return menu
    }

    private func createDisplayModeMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for mode in DisplayMode.allCases {
            let menuItem = NSMenuItem(title: mode.rawValue, action: #selector(displayModeSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = mode.rawValue
            menuItem.state = (currentDisplayMode == mode) ? .on : .off
            submenu.addItem(menuItem)
        }
        item.submenu = submenu
        return item
    }

    private func createMonitoringIntervalMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Rate", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for interval in MonitorConstants.availableIntervals {
            let title = interval < 1.0 ? "\(interval)s" : "\(Int(interval))s"
            let menuItem = NSMenuItem(title: title, action: #selector(monitoringIntervalSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = interval
            menuItem.state = (currentMonitoringInterval == interval) ? .on : .off
            submenu.addItem(menuItem)
        }
        item.submenu = submenu
        return item
    }

    private func createServiceCategoryMenu(for category: ServiceCategory) -> NSMenuItem {
        let item = NSMenuItem(title: category.displayName, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for endpoint in ServiceManager.shared.getEndpoints(for: category) {
            let menuItem = NSMenuItem(title: endpoint.name, action: #selector(serviceSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = endpoint
            menuItem.state = (endpoint.name == currentEndpoint?.name) ? .on : .off
            submenu.addItem(menuItem)
        }
        item.submenu = submenu
        return item
    }

    private func createAboutMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "About", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let versionItem = NSMenuItem(title: "Version: \(AppConstants.Version.current)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        submenu.addItem(versionItem)

        let buildItem = NSMenuItem(title: "Build: \(AppConstants.Version.build)", action: nil, keyEquivalent: "")
        buildItem.isEnabled = false
        submenu.addItem(buildItem)

        submenu.addItem(NSMenuItem.separator())

        let copyrightItem = NSMenuItem(title: "© 2025 iMoni App", action: nil, keyEquivalent: "")
        copyrightItem.isEnabled = false
        submenu.addItem(copyrightItem)

        item.submenu = submenu
        return item
    }

    private func createQuitMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        item.target = self
        return item
    }

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
        if currentDisplayMode != .serviceLatency {
            currentDisplayMode = .serviceLatency
        }
        switchToEndpoint(endpoint)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func loadSettings() {
        currentDisplayMode = ConfigurationManager.shared.getDisplayMode()
        currentMonitoringInterval = ConfigurationManager.shared.getMonitoringInterval()
        if let savedServiceName = ConfigurationManager.shared.getLastSelectedService() {
            if let savedEndpoint = ServiceManager.shared.endpoints.first(where: { $0.name == savedServiceName }) {
                currentEndpoint = savedEndpoint
            }
        }
    }

    private func saveSettings() {
        ConfigurationManager.shared.setDisplayMode(currentDisplayMode)
        ConfigurationManager.shared.setMonitoringInterval(currentMonitoringInterval)
        if let endpoint = currentEndpoint {
            ConfigurationManager.shared.setLastSelectedService(endpoint.name)
        }
    }

    private func switchToEndpoint(_ endpoint: ServiceEndpoint) {
        currentEndpoint = endpoint
        latencyMonitor.startMonitoring(endpoint)
        updateCombinedDisplay()
        saveSettings()
    }

    private func updateCombinedDisplay() {
        let displayText = createDisplayText()
        Utilities.safeMainQueueCallback { [weak self] in
            guard let self = self else { return }
            if let button = self.statusBarItem?.button {
                let color: NSColor = self.connectionStatus == .connected ? .labelColor : .systemRed
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
                button.attributedTitle = NSAttributedString(string: displayText, attributes: attrs)
                button.toolTip = self.createTooltip()
            }
        }
    }

    private func createDisplayText() -> String {
        switch currentDisplayMode {
        case .serviceLatency:
            let serviceName = currentEndpoint?.name ?? AppConstants.defaultValue
            if connectionStatus != .connected {
                return "\(serviceName): \(AppConstants.defaultValue)"
            }
            return "\(serviceName): \(Utilities.formatLatency(rawLatency))"
        case .networkSpeed:
            return "↓\(currentDownloadSpeed) ↑\(currentUploadSpeed)"
        }
    }

    private func createTooltip() -> String {
        var tooltip = "iMoni - Network Monitor\n"
        switch currentDisplayMode {
        case .serviceLatency:
            if let endpoint = currentEndpoint {
                tooltip += "Service: \(endpoint.name)\nHost: \(endpoint.host):\(endpoint.port)\n"
                tooltip += "Latency: \(Utilities.formatLatency(rawLatency))\n"
            } else {
                tooltip += "No service selected\n"
            }
        case .networkSpeed:
            tooltip += "Download Speed: \(currentDownloadSpeed)\nUpload Speed: \(currentUploadSpeed)\n"
        }
        tooltip += "Update Rate: \(Utilities.formatInterval(currentMonitoringInterval))\n"
        tooltip += connectionStatus == .disconnected ? "Status: Disconnected" : "Status: Connected"
        return tooltip
    }

    // MARK: - MonitorLatencyDelegate

    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint) {
        rawLatency = latency
        connectionStatus = .connected
        updateCombinedDisplay()
    }

    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint) {
        rawLatency = 0.0
        connectionStatus = status
        updateCombinedDisplay()
    }

    // MARK: - MonitorNetworkDelegate

    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double, uploadSpeed: Double) {
        currentDownloadSpeed = Utilities.formatSpeed(downloadSpeed)
        currentUploadSpeed = Utilities.formatSpeed(uploadSpeed)
        connectionStatus = .connected
        updateCombinedDisplay()
    }

    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus) {
        currentDownloadSpeed = AppConstants.defaultValue
        currentUploadSpeed = AppConstants.defaultValue
        connectionStatus = status
        updateCombinedDisplay()
    }
}
