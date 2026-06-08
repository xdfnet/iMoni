import Cocoa

class MenuBarController: NSObject, MonitorLatencyDelegate, MonitorNetworkDelegate, NSMenuDelegate {
    private var statusBarItem: NSStatusItem?
    private let latencyMonitorDeepSeek = MonitorLatency()
    private let latencyMonitorOpenAI = MonitorLatency()
    private let networkMonitor = MonitorNetwork()
    private var deepSeekLatency: TimeInterval = 0
    private var openAILatency: TimeInterval = 0
    private var deepSeekConnected = false
    private var openAIConnected = false
    private var currentUploadSpeed = "--"
    private var currentDownloadSpeed = "--"
    private var connectionStatus: ConnectionStatus = .disconnected
    private var currentDisplayMode: DisplayMode = .serviceLatency

    override init() {
        super.init()
        loadSettings()
        setupStatusBar()
        setupMonitors()
        applySettings()
        updateDisplay()
    }

    func cleanup() {
        latencyMonitorDeepSeek.stopMonitoring()
        latencyMonitorOpenAI.stopMonitoring()
        networkMonitor.stopMonitoring()
        statusBarItem = nil
    }

    func suspend() {
        latencyMonitorDeepSeek.stopMonitoring()
        latencyMonitorOpenAI.stopMonitoring()
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
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
        }
        let menu = NSMenu()
        menu.delegate = self
        statusBarItem?.menu = menu
    }

    private func setupMonitors() {
        latencyMonitorDeepSeek.delegate = self
        latencyMonitorOpenAI.delegate = self
        networkMonitor.delegate = self
    }

    private func applySettings() {
        if currentDisplayMode == .serviceLatency {
            networkMonitor.stopMonitoring()
            latencyMonitorDeepSeek.startMonitoring(services[0])
            latencyMonitorOpenAI.startMonitoring(services[1])
        } else {
            latencyMonitorDeepSeek.stopMonitoring()
            latencyMonitorOpenAI.stopMonitoring()
            networkMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

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

        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let about = NSMenuItem(title: "iMoni v\(ver)", action: nil, keyEquivalent: "")
        about.isEnabled = false
        menu.addItem(about)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: raw) else { return }
        currentDisplayMode = mode
        saveSettings()
        applySettings()
        updateDisplay()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Settings

    private func loadSettings() {
        currentDisplayMode = UserDefaults.standard.displayMode
    }

    private func saveSettings() {
        UserDefaults.standard.displayMode = currentDisplayMode
    }

    // MARK: - Display

    private func updateDisplay() {
        let top: String
        let bottom: String
        let connected: Bool

        switch currentDisplayMode {
        case .serviceLatency:
            top = "OpenAI: \(openAIConnected ? formatLatency(openAILatency) : "--")"
            bottom = "DeepSeek: \(deepSeekConnected ? formatLatency(deepSeekLatency) : "--")"
            connected = deepSeekConnected || openAIConnected
            connectionStatus = connected ? .connected : .disconnected
        case .networkSpeed:
            top = "↑\(currentUploadSpeed)"
            bottom = "↓\(currentDownloadSpeed)"
            connected = connectionStatus == .connected
        }

        statusBarItem?.button?.image = renderImage(top: top, bottom: bottom, connected: connected)
        statusBarItem?.button?.toolTip = tooltipText
    }

    private func renderImage(top: String, bottom: String, connected: Bool) -> NSImage {
        let color = connected ? NSColor.labelColor : NSColor.systemRed
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]

        let topSize = (top as NSString).size(withAttributes: attrs)
        let bottomSize = (bottom as NSString).size(withAttributes: attrs)
        let width = max(topSize.width, bottomSize.width) + 6
        let height = NSStatusBar.system.thickness

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let halfH = height / 2
            (top as NSString).draw(at: NSPoint(x: 2, y: halfH + (halfH - topSize.height) / 2), withAttributes: attrs)
            (bottom as NSString).draw(at: NSPoint(x: 2, y: (halfH - bottomSize.height) / 2), withAttributes: attrs)
            return true
        }
    }

    private var tooltipText: String {
        if currentDisplayMode == .serviceLatency {
            return "iMoni\nOpenAI: \(openAIConnected ? formatLatency(openAILatency) : "--")\nDeepSeek: \(deepSeekConnected ? formatLatency(deepSeekLatency) : "--")\nStatus: \(deepSeekConnected || openAIConnected ? "Connected" : "Disconnected")"
        }
        return "iMoni\n↑ \(currentUploadSpeed)\n↓ \(currentDownloadSpeed)\nStatus: \(connectionStatus == .connected ? "Connected" : "Disconnected")"
    }

    // MARK: - MonitorLatencyDelegate

    func monitor(_ monitor: MonitorLatency, didUpdateLatency latency: TimeInterval, for endpoint: ServiceEndpoint) {
        if endpoint.name == "DeepSeek" {
            deepSeekLatency = latency
            deepSeekConnected = true
        } else if endpoint.name == "OpenAI" {
            openAILatency = latency
            openAIConnected = true
        }
        if currentDisplayMode == .serviceLatency { updateDisplay() }
    }

    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint) {
        if endpoint.name == "DeepSeek" {
            deepSeekLatency = 0
            deepSeekConnected = false
        } else if endpoint.name == "OpenAI" {
            openAILatency = 0
            openAIConnected = false
        }
        if currentDisplayMode == .serviceLatency { updateDisplay() }
    }

    // MARK: - MonitorNetworkDelegate

    func networkStats(_ stats: MonitorNetwork, didUpdateSpeed uploadSpeed: Double, downloadSpeed: Double) {
        currentUploadSpeed = formatSpeed(uploadSpeed)
        currentDownloadSpeed = formatSpeed(downloadSpeed)
        connectionStatus = .connected
        if currentDisplayMode == .networkSpeed { updateDisplay() }
    }

    func networkStats(_ stats: MonitorNetwork, didFailWithError status: ConnectionStatus) {
        currentDownloadSpeed = "--"
        connectionStatus = status
        if currentDisplayMode == .networkSpeed { updateDisplay() }
    }
}
