import Foundation

struct ConfigKeys {
    static let displayMode = "currentDisplayMode"
    static let monitoringInterval = "currentMonitoringInterval"
    static let lastSelectedService = "lastSelectedService"
    static let customEndpoints = "customEndpoints"
    static let enableNotifications = "enableNotifications"
}

class ConfigurationManager {
    static let shared = ConfigurationManager()

    private let defaults = UserDefaults.standard
    var onConfigurationChanged: (() -> Void)?

    private init() {
        registerDefaults()
    }

    func setDisplayMode(_ mode: DisplayMode) {
        defaults.set(mode.rawValue, forKey: ConfigKeys.displayMode)
        notifyConfigurationChanged()
    }

    func getDisplayMode() -> DisplayMode {
        if let rawValue = defaults.string(forKey: ConfigKeys.displayMode),
           let mode = DisplayMode(rawValue: rawValue) {
            return mode
        }
        return .serviceLatency
    }

    func setMonitoringInterval(_ interval: TimeInterval) {
        let validatedInterval = Utilities.clamp(interval, min: MonitorConstants.minInterval, max: MonitorConstants.maxInterval)
        defaults.set(validatedInterval, forKey: ConfigKeys.monitoringInterval)
        notifyConfigurationChanged()
    }

    func getMonitoringInterval() -> TimeInterval {
        let interval = defaults.double(forKey: ConfigKeys.monitoringInterval)
        if interval > 0 {
            return Utilities.clamp(interval, min: MonitorConstants.minInterval, max: MonitorConstants.maxInterval)
        }
        return MonitorConstants.defaultUserInterval
    }

    func setLastSelectedService(_ serviceName: String) {
        defaults.set(serviceName, forKey: ConfigKeys.lastSelectedService)
        notifyConfigurationChanged()
    }

    func getLastSelectedService() -> String? {
        defaults.string(forKey: ConfigKeys.lastSelectedService)
    }

    func setCustomEndpoints(_ endpoints: [ServiceEndpoint]) {
        let customData = endpoints.map { endpoint in
            [
                "name": endpoint.name,
                "host": endpoint.host,
                "port": endpoint.port,
            ] as [String: Any]
        }
        defaults.set(customData, forKey: ConfigKeys.customEndpoints)
        notifyConfigurationChanged()
    }

    func getCustomEndpoints() -> [ServiceEndpoint] {
        guard let customData = defaults.array(forKey: ConfigKeys.customEndpoints) as? [[String: Any]] else {
            return []
        }
        return customData.compactMap { data in
            guard let name = data["name"] as? String,
                  let host = data["host"] as? String,
                  let port = data["port"] as? Int else { return nil }
            return ServiceEndpoint(name: name, host: host, port: port)
        }
    }

    func setEnableNotifications(_ enabled: Bool) {
        defaults.set(enabled, forKey: ConfigKeys.enableNotifications)
        notifyConfigurationChanged()
    }

    func getEnableNotifications() -> Bool {
        defaults.bool(forKey: ConfigKeys.enableNotifications)
    }

    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "com.imoni"
        defaults.removePersistentDomain(forName: domain)
        notifyConfigurationChanged()
    }

    func exportConfiguration() -> Data? {
        let config: [String: Any] = [
            "displayMode": getDisplayMode().rawValue,
            "monitoringInterval": getMonitoringInterval(),
            "lastSelectedService": getLastSelectedService() ?? "",
            "customEndpoints": getCustomEndpoints().map { ["name": $0.name, "host": $0.host, "port": $0.port] },
            "enableNotifications": getEnableNotifications(),
            "exportDate": Date().timeIntervalSince1970,
        ]
        return try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
    }

    func importConfiguration(_ data: Data) -> Bool {
        guard let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }

        if let displayMode = config["displayMode"] as? String,
           let mode = DisplayMode(rawValue: displayMode) {
            setDisplayMode(mode)
        }
        if let interval = config["monitoringInterval"] as? TimeInterval {
            setMonitoringInterval(interval)
        }
        if let serviceName = config["lastSelectedService"] as? String {
            setLastSelectedService(serviceName)
        }
        if let customEndpointsData = config["customEndpoints"] as? [[String: Any]] {
            let customEndpoints: [ServiceEndpoint] = customEndpointsData.compactMap { data in
                guard let name = data["name"] as? String,
                      let host = data["host"] as? String,
                      let port = data["port"] as? Int else { return nil }
                return ServiceEndpoint(name: name, host: host, port: port)
            }
            setCustomEndpoints(customEndpoints)
        }
        if let enableNotifications = config["enableNotifications"] as? Bool {
            setEnableNotifications(enableNotifications)
        }
        notifyConfigurationChanged()
        return true
    }

    private func registerDefaults() {
        let defaultValues: [String: Any] = [ConfigKeys.enableNotifications: true]
        defaults.register(defaults: defaultValues)
    }

    private func notifyConfigurationChanged() {
        Utilities.safeMainQueueCallback {
            self.onConfigurationChanged?()
        }
    }
}
