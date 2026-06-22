import Cocoa

class MenuBarController: NSObject, MonitorLatencyDelegate, MonitorNetworkDelegate, MonitorMemoryDelegate, MonitorCPUDelegate, MonitorGPUDelegate, NSMenuDelegate {
    private var statusBarItem: NSStatusItem?
    private let latencyMonitorDeepSeek = MonitorLatency()
    private let latencyMonitorOpenAI = MonitorLatency()
    private let networkMonitor = MonitorNetwork()
    private let memoryMonitor = MonitorMemory()
    private let cpuMonitor = MonitorCPU()
    private let gpuMonitor = MonitorGPU()
    private var deepSeekLatency: TimeInterval = 0
    private var openAILatency: TimeInterval = 0
    private var deepSeekConnected = false
    private var openAIConnected = false
    private var currentUploadSpeed = ""
    private var currentDownloadSpeed = ""
    private var currentMemoryUsed: Double = 0
    private var currentMemoryPercent: Double = 0
    private var memoryAvailable = false
    private var currentCPUPercent: Double = 0
    private var currentGPUPercent: Double = 0
    private var cpuAvailable = false
    private var gpuAvailable = false
    private var connectionStatus: ConnectionStatus = .disconnected
    private var currentDisplayMode: DisplayMode = .latency

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
        memoryMonitor.stopMonitoring()
        cpuMonitor.stopMonitoring()
        gpuMonitor.stopMonitoring()
        statusBarItem = nil
    }

    func suspend() {
        latencyMonitorDeepSeek.stopMonitoring()
        latencyMonitorOpenAI.stopMonitoring()
        networkMonitor.stopMonitoring()
        memoryMonitor.stopMonitoring()
        cpuMonitor.stopMonitoring()
        gpuMonitor.stopMonitoring()
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
        memoryMonitor.delegate = self
        cpuMonitor.delegate = self
        gpuMonitor.delegate = self
    }

    private func applySettings() {
        switch currentDisplayMode {
        case .latency:
            networkMonitor.stopMonitoring()
            memoryMonitor.stopMonitoring()
            cpuMonitor.stopMonitoring()
            gpuMonitor.stopMonitoring()
            latencyMonitorDeepSeek.startMonitoring(services[0])
            latencyMonitorOpenAI.startMonitoring(services[1])
        case .networkSpeed:
            latencyMonitorDeepSeek.stopMonitoring()
            latencyMonitorOpenAI.stopMonitoring()
            memoryMonitor.stopMonitoring()
            cpuMonitor.stopMonitoring()
            gpuMonitor.stopMonitoring()
            networkMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .memoryUsage:
            latencyMonitorDeepSeek.stopMonitoring()
            latencyMonitorOpenAI.stopMonitoring()
            networkMonitor.stopMonitoring()
            cpuMonitor.stopMonitoring()
            gpuMonitor.stopMonitoring()
            memoryMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .systemUsage:
            latencyMonitorDeepSeek.stopMonitoring()
            latencyMonitorOpenAI.stopMonitoring()
            networkMonitor.stopMonitoring()
            memoryMonitor.stopMonitoring()
            cpuMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
            gpuMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        for (i, mode) in DisplayMode.allCases.enumerated() {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(selectMode(_:)), keyEquivalent: "\(i + 1)")
            item.target = self
            item.keyEquivalentModifierMask = .command
            item.representedObject = mode.rawValue
            item.state = mode == currentDisplayMode ? .on : .off
            menu.addItem(item)
        }
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

        switch currentDisplayMode {
        case .latency:
            top = openAIConnected ? "OpenAI: \(formatLatency(openAILatency))" : ""
            bottom = deepSeekConnected ? "DeepSeek: \(formatLatency(deepSeekLatency))" : ""
            connectionStatus = (deepSeekConnected || openAIConnected) ? .connected : .disconnected
        case .networkSpeed:
            top = "\(currentUploadSpeed)"
            bottom = "\(currentDownloadSpeed)"
        case .memoryUsage:
            if memoryAvailable {
                let used = Int(round(currentMemoryUsed))
                let pct = currentMemoryPercent
                let total = pct > 0 ? Int(round(currentMemoryUsed / (pct / 100))) : 0
                top = "\(used)/\(total) GB"
                bottom = "PCT \(Int(round(pct)))%"
            } else {
                top = ""
                bottom = ""
            }
        case .systemUsage:
            top = cpuAvailable ? "CPU\(String(format: "%3d%%", Int(round(currentCPUPercent))))" : ""
            bottom = gpuAvailable ? "GPU\(String(format: "%3d%%", Int(round(currentGPUPercent))))" : ""
        }

        statusBarItem?.button?.image = renderImage(top: top, bottom: bottom)
        statusBarItem?.button?.toolTip = tooltipText
    }

    private func renderImage(top: String, bottom: String) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .light)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]

        let topSize = (top as NSString).size(withAttributes: attrs)
        let bottomSize = (bottom as NSString).size(withAttributes: attrs)
        let width = max(topSize.width, bottomSize.width) + 6
        let height = NSStatusBar.system.thickness

        return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let halfH = height / 2
            (top as NSString).draw(at: NSPoint(x: width - topSize.width - 2, y: halfH + (halfH - topSize.height) / 2), withAttributes: attrs)
            (bottom as NSString).draw(at: NSPoint(x: width - bottomSize.width - 2, y: (halfH - bottomSize.height) / 2), withAttributes: attrs)
            return true
        }
    }

    private var tooltipText: String {
        switch currentDisplayMode {
        case .latency:
            return "iMoni\nOpenAI: \(openAIConnected ? formatLatency(openAILatency) : "--")\nDeepSeek: \(deepSeekConnected ? formatLatency(deepSeekLatency) : "--")\nStatus: \(deepSeekConnected || openAIConnected ? "Connected" : "Disconnected")"
        case .networkSpeed:
            return "iMoni\n↑ \(currentUploadSpeed)\n↓ \(currentDownloadSpeed)\nStatus: \(connectionStatus == .connected ? "Connected" : "Disconnected")"
        case .memoryUsage:
            let used = Int(round(currentMemoryUsed))
            let pctVal = currentMemoryPercent
            let total = pctVal > 0 ? Int(round(currentMemoryUsed / (pctVal / 100))) : 0
            return "iMoni\n\(used)/\(total) GB (\(Int(round(pctVal)))%)\nStatus: \(memoryAvailable ? "OK" : "Failed")"
        case .systemUsage:
            let cpuStr = cpuAvailable ? "\(Int(round(currentCPUPercent)))%" : "--"
            let gpuStr = gpuAvailable ? "\(Int(round(currentGPUPercent)))%" : "--"
            return "iMoni\nCPU: \(cpuStr)\nGPU: \(gpuStr)"
        }
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
        if currentDisplayMode == .latency { updateDisplay() }
    }

    func monitor(_ monitor: MonitorLatency, didFailWithError status: ConnectionStatus, for endpoint: ServiceEndpoint) {
        if endpoint.name == "DeepSeek" {
            deepSeekLatency = 0
            deepSeekConnected = false
        } else if endpoint.name == "OpenAI" {
            openAILatency = 0
            openAIConnected = false
        }
        if currentDisplayMode == .latency { updateDisplay() }
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

    // MARK: - MonitorMemoryDelegate

    func memoryMonitor(_ monitor: MonitorMemory, didUpdateMemoryUsed usedGB: Double, percent: Double) {
        currentMemoryUsed = usedGB
        currentMemoryPercent = percent
        memoryAvailable = true
        if currentDisplayMode == .memoryUsage { updateDisplay() }
    }

    func memoryMonitorDidFail(_ monitor: MonitorMemory) {
        memoryAvailable = false
        if currentDisplayMode == .memoryUsage { updateDisplay() }
    }

    // MARK: - MonitorCPUDelegate

    func cpuMonitor(_ monitor: MonitorCPU, didUpdateCPUUsage percent: Double) {
        currentCPUPercent = percent
        cpuAvailable = true
        if currentDisplayMode == .systemUsage { updateDisplay() }
    }

    func cpuMonitorDidFail(_ monitor: MonitorCPU) {
        cpuAvailable = false
        if currentDisplayMode == .systemUsage { updateDisplay() }
    }

    // MARK: - MonitorGPUDelegate

    func gpuMonitor(_ monitor: MonitorGPU, didUpdateGPUUsage percent: Double) {
        currentGPUPercent = percent
        gpuAvailable = true
        if currentDisplayMode == .systemUsage { updateDisplay() }
    }

    func gpuMonitorDidFail(_ monitor: MonitorGPU) {
        gpuAvailable = false
        if currentDisplayMode == .systemUsage { updateDisplay() }
    }
}
