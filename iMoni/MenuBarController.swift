import Cocoa

class MenuBarController: NSObject, MonitorNetworkDelegate, MonitorMemoryDelegate, MonitorCPUDelegate, MonitorGPUDelegate, NSMenuDelegate {
    private var statusBarItem: NSStatusItem?
    private let networkMonitor = MonitorNetwork()
    private let memoryMonitor = MonitorMemory()
    private let cpuMonitor = MonitorCPU()
    private let gpuMonitor = MonitorGPU()
    private var currentUploadSpeed: Double = 0
    private var currentDownloadSpeed: Double = 0
    private var networkAvailable = false
    private var currentMemoryUsed: Double = 0
    private var currentMemoryPercent: Double = 0
    private var memoryAvailable = false
    private var currentCPUPercent: Double = 0
    private var currentGPUPercent: Double = 0
    private var cpuAvailable = false
    private var gpuAvailable = false
    private var currentDisplayMode: DisplayMode = .networkSpeed

    override init() {
        super.init()
        loadSettings()
        setupStatusBar()
        setupMonitors()
        applySettings()
        updateDisplay()
    }

    func cleanup() {
        networkMonitor.stopMonitoring()
        memoryMonitor.stopMonitoring()
        cpuMonitor.stopMonitoring()
        gpuMonitor.stopMonitoring()
        statusBarItem = nil
    }

    func suspend() {
        networkMonitor.stopMonitoring()
        memoryMonitor.stopMonitoring()
        cpuMonitor.stopMonitoring()
        gpuMonitor.stopMonitoring()
        networkAvailable = false
        memoryAvailable = false
        cpuAvailable = false
        gpuAvailable = false
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
        let menu = NSMenu()
        menu.delegate = self
        statusBarItem?.menu = menu
    }

    private func setupMonitors() {
        networkMonitor.delegate = self
        memoryMonitor.delegate = self
        cpuMonitor.delegate = self
        gpuMonitor.delegate = self
    }

    private func applySettings() {
        switch currentDisplayMode {
        case .networkSpeed:
            memoryMonitor.stopMonitoring()
            cpuMonitor.stopMonitoring()
            gpuMonitor.stopMonitoring()
            networkMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .memoryUsage:
            networkMonitor.stopMonitoring()
            cpuMonitor.stopMonitoring()
            gpuMonitor.stopMonitoring()
            memoryMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .systemUsage:
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
        case .networkSpeed:
            top = networkAvailable ? formatSpeed(currentUploadSpeed) : ""
            bottom = networkAvailable ? formatSpeed(currentDownloadSpeed) : ""
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
        case .networkSpeed:
            return "iMoni\n↑ \(networkAvailable ? formatSpeed(currentUploadSpeed) : "--")\n↓ \(networkAvailable ? formatSpeed(currentDownloadSpeed) : "--")\nStatus: \(networkAvailable ? "Connected" : "Disconnected")"
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

    // MARK: - MonitorNetworkDelegate

    func networkStats(_ stats: MonitorNetwork, didUpdateSpeed uploadSpeed: Double, downloadSpeed: Double) {
        currentUploadSpeed = uploadSpeed
        currentDownloadSpeed = downloadSpeed
        networkAvailable = true
        if currentDisplayMode == .networkSpeed { updateDisplay() }
    }

    func networkStatsDidFail(_ stats: MonitorNetwork) {
        networkAvailable = false
        currentUploadSpeed = 0
        currentDownloadSpeed = 0
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
        currentMemoryUsed = 0
        currentMemoryPercent = 0
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
        currentCPUPercent = 0
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
        currentGPUPercent = 0
        if currentDisplayMode == .systemUsage { updateDisplay() }
    }
}
