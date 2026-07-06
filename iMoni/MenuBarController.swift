import Cocoa

class MenuBarController: NSObject, MonitorNetworkDelegate, MonitorMemoryDelegate, MonitorCPUDelegate, MonitorGPUDelegate, MonitorStabilityDelegate, NSMenuDelegate {
    private func stopAllMonitors() {
        networkMonitor.stopMonitoring()
        memoryMonitor.stopMonitoring()
        cpuMonitor.stopMonitoring()
        gpuMonitor.stopMonitoring()
        stabilityMonitor.stopMonitoring()
    }
    private var statusBarItem: NSStatusItem?
    private let networkMonitor = MonitorNetwork()
    private let memoryMonitor = MonitorMemory()
    private let cpuMonitor = MonitorCPU()
    private let gpuMonitor = MonitorGPU()
    private let stabilityMonitor = MonitorStability()
    private var currentUploadSpeed: Int64 = 0
    private var currentDownloadSpeed: Int64 = 0
    private var currentMemoryUsed: Double = 0
    private var currentMemoryPercent: Double = 0
    private var currentCPUPercent: Double = 0
    private var currentGPUPercent: Double = 0
    private var currentCPUAvailable = false
    private var currentGPUAvailable = false
    private var currentLatency: Double = -2  // <0 = no data/timeout
    private var currentLossRate: Double = 0
    private var currentJitter: Double = 0
    private var currentDisplayMode: DisplayMode = .networkSpeed
    private let menuBarView = MenuBarView()

    override init() {
        super.init()
        loadSettings()
        setupStatusBar()
        setupMonitors()
        applySettings()
        updateDisplay()
    }

    func cleanup() {
        stopAllMonitors()
        statusBarItem = nil
    }

    func suspend() {
        stopAllMonitors()
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

        guard let button = statusBarItem?.button else { return }
        let h = button.bounds.height
        menuBarView.frame = CGRect(x: 0, y: 2, width: 50, height: h - 4)
        button.addSubview(menuBarView)
        button.image = NSImage()

        menuBarView.onWidthChange = { [weak self] width in
            self?.statusBarItem?.length = width
        }
    }

    private func setupMonitors() {
        networkMonitor.delegate = self
        memoryMonitor.delegate = self
        cpuMonitor.delegate = self
        gpuMonitor.delegate = self
        stabilityMonitor.delegate = self
    }

    private func applySettings() {
        stopAllMonitors()
        currentUploadSpeed = 0; currentDownloadSpeed = 0
        currentMemoryUsed = 0; currentMemoryPercent = 0
        currentCPUPercent = 0; currentGPUPercent = 0
        currentCPUAvailable = false; currentGPUAvailable = false
        currentLatency = -2; currentLossRate = 0; currentJitter = 0
        menuBarView.resetMaxWidth()
        switch currentDisplayMode {
        case .networkSpeed:
            networkMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .memoryUsage:
            memoryMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .cpuGpu:
            cpuMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
            gpuMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        case .stability:
            stabilityMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
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
            top = "NET"
            bottom = formatSpeed(currentDownloadSpeed)
        case .memoryUsage:
            (top, bottom) = formatMemoryGB(currentMemoryUsed, percent: currentMemoryPercent)
        case .cpuGpu:
            top = "CPU/GPU"
            let cpuStr = currentCPUAvailable ? formatCPUPercent(currentCPUPercent) : "--%"
            let gpuStr = currentGPUAvailable ? formatCPUPercent(currentGPUPercent) : "--%"
            bottom = "\(cpuStr) \(gpuStr)"
        case .stability:
            top = "RTT"
            bottom = formatLatency(currentLatency)
        }

        mainQueue { [weak self] in
            guard let self else { return }
            self.menuBarView.updateText(top: top, bottom: bottom)
            self.statusBarItem?.button?.toolTip = self.tooltipText
        }
    }

    private var tooltipText: String {
        switch currentDisplayMode {
        case .networkSpeed:
            return "iMoni\n↑ \(formatSpeed(currentUploadSpeed))\n↓ \(formatSpeed(currentDownloadSpeed))"
        case .memoryUsage:
            let (_, bottom) = formatMemoryGB(currentMemoryUsed, percent: currentMemoryPercent)
            let pct = Int(round(currentMemoryPercent))
            return "iMoni\n\(bottom) (\(pct)%)"
        case .cpuGpu:
            let cpu = currentCPUAvailable ? "\(Int(round(currentCPUPercent)))%" : "---"
            let gpu = currentGPUAvailable ? "\(Int(round(currentGPUPercent)))%" : "---"
            return "iMoni\nCPU: \(cpu)\nGPU: \(gpu)"
        case .stability:
            return "iMoni\nhttps://www.google.com\n\(formatLatency(currentLatency))\n丢包 \(formatLossRate(currentLossRate))  抖动 \(formatJitter(currentJitter))"
        }
    }

    // MARK: - MonitorNetworkDelegate

    func networkMonitor(_ monitor: MonitorNetwork, didUpdateSpeed uploadSpeed: Int64, downloadSpeed: Int64) {
        currentUploadSpeed = uploadSpeed
        currentDownloadSpeed = downloadSpeed
        NSLog("[Network] ↓ %@  ↑ %@", formatSpeed(downloadSpeed), formatSpeed(uploadSpeed))
        updateDisplay()
    }

    func networkMonitorDidFail(_ monitor: MonitorNetwork) {
        currentUploadSpeed = 0
        currentDownloadSpeed = 0
        updateDisplay()
    }

    // MARK: - MonitorMemoryDelegate

    func memoryMonitor(_ monitor: MonitorMemory, didUpdateMemoryUsed usedGB: Double, percent: Double) {
        currentMemoryUsed = usedGB
        currentMemoryPercent = percent
        NSLog("[Memory] %@  %@", formatMemoryGB(usedGB, percent: percent).top, formatMemoryGB(usedGB, percent: percent).bottom)
        updateDisplay()
    }

    func memoryMonitorDidFail(_ monitor: MonitorMemory) {
        currentMemoryUsed = 0
        currentMemoryPercent = 0
        updateDisplay()
    }

    // MARK: - MonitorCPUDelegate

    func cpuMonitor(_ monitor: MonitorCPU, didUpdateCPUUsage percent: Double) {
        currentCPUPercent = percent
        currentCPUAvailable = true
        NSLog("[CPU] CPU: %.1f%%", percent)
        updateDisplay()
    }

    func cpuMonitorDidFail(_ monitor: MonitorCPU) {
        currentCPUPercent = 0
        updateDisplay()
    }

    // MARK: - MonitorGPUDelegate

    func gpuMonitor(_ monitor: MonitorGPU, didUpdateGPUUsage percent: Double) {
        currentGPUPercent = percent
        currentGPUAvailable = true
        NSLog("[GPU] GPU: %.1f%%", percent)
        updateDisplay()
    }

    func gpuMonitorDidFail(_ monitor: MonitorGPU) {
        currentGPUPercent = 0
        updateDisplay()
    }

    // MARK: - MonitorStabilityDelegate

    func stabilityMonitor(_ monitor: MonitorStability, didUpdateLatency latency: Double, lossRate: Double, jitter: Double) {
        currentLatency = latency
        currentLossRate = lossRate
        currentJitter = jitter
        NSLog("[Stability] Top: %.0fms  ✕%.1f%%  ±%.1fms", latency, lossRate * 100, jitter)
        updateDisplay()
    }

    func stabilityMonitorDidFail(_ monitor: MonitorStability) {
        currentLatency = -2
        currentLossRate = 1.0
        currentJitter = 0
        updateDisplay()
    }
}

// MARK: - MenuBarView

class MenuBarView: NSView {
    var topText = "" { didSet { needsDisplay = true } }
    var bottomText = "" { didSet { needsDisplay = true } }
    var onWidthChange: ((CGFloat) -> Void)?

    private var maxWidth: CGFloat = 0

    func resetMaxWidth() { maxWidth = 0 }

    func updateText(top: String, bottom: String) {
        topText = top
        bottomText = bottom
        resizeToFit()
        needsDisplay = true
    }

    private func resizeToFit() {
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right
        let topSize = (topText as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 7, weight: .light), .paragraphStyle: rightStyle])
        let bottomSize = (bottomText as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .regular), .paragraphStyle: rightStyle])
        let rawWidth = max(topSize.width, bottomSize.width) + 6
        if rawWidth > maxWidth { maxWidth = rawWidth }
        let newWidth = ceil(maxWidth / 5) * 5
        if abs(newWidth - frame.width) > 0.5 {
            setFrameSize(NSSize(width: newWidth, height: frame.height))
            onWidthChange?(newWidth)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let rightStyle = NSMutableParagraphStyle()
        rightStyle.alignment = .right
        let topAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7, weight: .light),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: rightStyle
        ]
        let bottomAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: rightStyle
        ]

        let topRect = CGRect(x: 0, y: 12, width: bounds.width - 4, height: 7)
        (topText as NSString).draw(in: topRect, withAttributes: topAttrs)

        let bottomRect = CGRect(x: 0, y: 1, width: bounds.width - 4, height: 13)
        (bottomText as NSString).draw(in: bottomRect, withAttributes: bottomAttrs)
    }
}
