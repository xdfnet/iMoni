import Cocoa

class MenuBarController: NSObject, MonitorLatencyDelegate, MonitorNetworkDelegate {
    private var statusBarItem: NSStatusItem?
    private let latencyMonitor = MonitorLatency()
    private let networkMonitor = MonitorNetwork()
    private var currentEndpoint: ServiceEndpoint?
    private var rawLatency: TimeInterval = 0
    private var currentDownloadSpeed = "--"
    private var connectionStatus: ConnectionStatus = .disconnected
    private var currentDisplayMode: DisplayMode = .serviceLatency
    private var currentInterval: TimeInterval = MonitorConstants.defaultInterval

    override init() {
        super.init()
        loadSettings()
        setupStatusBar()
        setupMonitors()
        applySettings()
        updateDisplay()
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
        if statusBarItem == nil { setupStatusBar() }
        applySettings()
        updateDisplay()
    }

    // MARK: - Setup

    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
    }

    private func setupMonitors() {
        latencyMonitor.delegate = self
        networkMonitor.delegate = self
    }

    private func applySettings() {
        if currentDisplayMode == .serviceLatency {
            if let endpoint = currentEndpoint {
                latencyMonitor.startMonitoring(endpoint)
            } else {
                currentEndpoint = services.first
                if let endpoint = currentEndpoint { latencyMonitor.startMonitoring(endpoint) }
            }
            networkMonitor.stopMonitoring()
        } else {
            latencyMonitor.stopMonitoring()
            networkMonitor.startMonitoring(interval: currentInterval)
        }
    }

    private func switchTo(_ endpoint: ServiceEndpoint) {
        currentEndpoint = endpoint
        latencyMonitor.startMonitoring(endpoint)
        saveSettings()
        updateDisplay()
    }

    // MARK: - Menu

    @objc private func statusBarButtonClicked() {
        statusBarItem?.menu = buildMenu()
        statusBarItem?.button?.performClick(nil)
        statusBarItem?.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let viewItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let viewSub = NSMenu()
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentDisplayMode ? .on : .off
            viewSub.addItem(item)
        }
        viewItem.submenu = viewSub
        menu.addItem(viewItem)
        menu.addItem(.separator())

        let serviceItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let serviceSub = NSMenu()
        for svc in services {
            let item = NSMenuItem(title: svc.name, action: #selector(selectService(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = svc
            item.state = svc.name == currentEndpoint?.name ? .on : .off
            serviceSub.addItem(item)
        }
        serviceItem.submenu = serviceSub
        menu.addItem(serviceItem)
        menu.addItem(.separator())

        let rateItem = NSMenuItem(title: "Rate", action: nil, keyEquivalent: "")
        let rateSub = NSMenu()
        for interval in MonitorConstants.availableIntervals {
            let title = interval < 1 ? "\(interval)s" : "\(Int(interval))s"
            let item = NSMenuItem(title: title, action: #selector(selectInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = interval
            item.state = interval == currentInterval ? .on : .off
            rateSub.addItem(item)
        }
        rateItem.submenu = rateSub
        menu.addItem(rateItem)
        menu.addItem(.separator())

        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let about = NSMenuItem(title: "iMoni v\(ver)", action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = DisplayMode(rawValue: raw) else { return }
        currentDisplayMode = mode
        saveSettings()
        applySettings()
        updateDisplay()
    }

    @objc private func selectService(_ sender: NSMenuItem) {
        guard let endpoint = sender.representedObject as? ServiceEndpoint else { return }
        if currentDisplayMode != .serviceLatency {
            currentDisplayMode = .serviceLatency
        }
        switchTo(endpoint)
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else { return }
        currentInterval = interval
        saveSettings()
        latencyMonitor.updateInterval(interval)
        networkMonitor.updateInterval(interval)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Settings

    private func loadSettings() {
        let ud = UserDefaults.standard
        currentDisplayMode = ud.displayMode
        currentInterval = ud.monitoringInterval
        if let name = ud.lastServiceName {
            currentEndpoint = services.first { $0.name == name }
        }
    }

    private func saveSettings() {
        let ud = UserDefaults.standard
        ud.displayMode = currentDisplayMode
        ud.monitoringInterval = currentInterval
        ud.lastServiceName = currentEndpoint?.name
    }

    // MARK: - Display

    private func updateDisplay() {
        let text: String
        switch currentDisplayMode {
        case .serviceLatency:
            let name = currentEndpoint?.name ?? "--"
            if connectionStatus != .connected { text = "\(name): --" }
            else { text = "\(name): \(formatLatency(rawLatency))" }
        case .networkSpeed:
            text = "↓\(currentDownloadSpeed)"
        }
        mainQueue { [weak self] in
            guard let self = self else { return }
            if let button = self.statusBarItem?.button {
                let color: NSColor = self.connectionStatus == .connected ? .labelColor : .systemRed
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
                button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
                button.toolTip = self.tooltipText
            }
        }
    }

    private var tooltipText: String {
        var tip = "iMoni\n"
        switch currentDisplayMode {
        case .serviceLatency:
            if let ep = currentEndpoint {
                tip += "\(ep.name) (\(ep.host):\(ep.port))\nLatency: \(formatLatency(rawLatency))\n"
            }
        case .networkSpeed:
            tip += "↓ \(currentDownloadSpeed)\n"
        }
        tip += "Rate: \(currentInterval < 1 ? "\(currentInterval)s" : "\(Int(currentInterval))s")\n"
        tip += connectionStatus == .connected ? "Status: Connected" : "Status: Disconnected"
        return tip
    }

    // MARK: - MonitorLatencyDelegate

    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint) {
        rawLatency = latency
        connectionStatus = .connected
        updateDisplay()
    }

    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint) {
        rawLatency = 0
        connectionStatus = status
        updateDisplay()
    }

    // MARK: - MonitorNetworkDelegate

    func networkStats(_ stats: MonitorNetwork, didUpdateDownloadSpeed downloadSpeed: Double) {
        currentDownloadSpeed = formatSpeed(downloadSpeed)
        connectionStatus = .connected
        updateDisplay()
    }

    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus) {
        currentDownloadSpeed = "--"
        connectionStatus = status
        updateDisplay()
    }
}
