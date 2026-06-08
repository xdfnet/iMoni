import Cocoa

class MenuBarController: NSObject, MonitorLatencyDelegate, MonitorNetworkDelegate {
    private var statusBarItem: NSStatusItem?
    private var speedView: NetworkSpeedView?
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
        let view = NetworkSpeedView(frame: NSRect(x: 0, y: 0, width: 120, height: NSStatusBar.system.thickness))
        view.onClick = { [weak self] in
            guard let self else { return }
            let menu = self.buildMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
        }
        statusBarItem?.view = view
        speedView = view
    }

    private func setupMonitors() {
        latencyMonitorDeepSeek.delegate = self
        latencyMonitorOpenAI.delegate = self
        networkMonitor.delegate = self
    }

    private func applySettings() {
        if currentDisplayMode == .serviceLatency {
            networkMonitor.stopMonitoring()
            latencyMonitorDeepSeek.startMonitoring(services[0]) // DeepSeek
            latencyMonitorOpenAI.startMonitoring(services[1])   // OpenAI
        } else {
            latencyMonitorDeepSeek.stopMonitoring()
            latencyMonitorOpenAI.stopMonitoring()
            networkMonitor.startMonitoring(interval: MonitorConstants.defaultInterval)
        }
    }

    // MARK: - Menu

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
        guard let view = speedView else { return }

        switch currentDisplayMode {
        case .serviceLatency:
            let top = "OpenAI: \(openAIConnected ? formatLatency(openAILatency) : "--")"
            let bottom = "DeepSeek: \(deepSeekConnected ? formatLatency(deepSeekLatency) : "--")"
            view.topText = top
            view.bottomText = bottom
            connectionStatus = deepSeekConnected || openAIConnected ? .connected : .disconnected
            view.isConnected = connectionStatus == .connected

            let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
            let attrs = [NSAttributedString.Key.font: font]
            let tw = (top as NSString).size(withAttributes: attrs).width
            let bw = (bottom as NSString).size(withAttributes: attrs).width
            statusBarItem?.length = max(tw, bw) + 8

        case .networkSpeed:
            view.topText = "↑\(currentUploadSpeed)"
            view.bottomText = "↓\(currentDownloadSpeed)"
            view.isConnected = connectionStatus == .connected

            let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
            let attrs = [NSAttributedString.Key.font: font]
            let tw = (view.topText as NSString).size(withAttributes: attrs).width
            let bw = (view.bottomText as NSString).size(withAttributes: attrs).width
            statusBarItem?.length = max(tw, bw) + 8
        }

        view.needsDisplay = true
        view.toolTip = tooltipText
    }

    private var tooltipText: String {
        if currentDisplayMode == .serviceLatency {
            return """
            iMoni
            OpenAI: \(openAIConnected ? formatLatency(openAILatency) : "--")
            DeepSeek: \(deepSeekConnected ? formatLatency(deepSeekLatency) : "--")
            Status: \(deepSeekConnected || openAIConnected ? "Connected" : "Disconnected")
            """
        } else {
            return """
            iMoni
            ↑ \(currentUploadSpeed)
            ↓ \(currentDownloadSpeed)
            Status: \(connectionStatus == .connected ? "Connected" : "Disconnected")
            """
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

// MARK: - Custom Menu Bar View

class NetworkSpeedView: NSView {
    var topText: String = "" { didSet { needsDisplay = true } }
    var bottomText: String = "" { didSet { needsDisplay = true } }
    var isConnected: Bool = true { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let color = isConnected ? NSColor.labelColor : NSColor.systemRed
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let halfH = bounds.height / 2
        let leftX: CGFloat = 2

        let top = topText as NSString
        let ts = top.size(withAttributes: attrs)
        top.draw(at: NSPoint(x: leftX, y: halfH + (halfH - ts.height) / 2),
                 withAttributes: attrs)

        let bottom = bottomText as NSString
        let bs = bottom.size(withAttributes: attrs)
        bottom.draw(at: NSPoint(x: leftX, y: (halfH - bs.height) / 2),
                    withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
