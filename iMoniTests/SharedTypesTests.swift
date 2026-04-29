import XCTest
@testable import iMoni

final class SharedTypesTests: XCTestCase {
    // MARK: - ServiceEndpoint
    func testServiceEndpoint_defaultPort() {
        let ep = ServiceEndpoint(name: "Test", host: "example.com")
        XCTAssertEqual(ep.name, "Test")
        XCTAssertEqual(ep.host, "example.com")
        XCTAssertEqual(ep.port, 443)
    }

    func testServiceEndpoint_customPort() {
        let ep = ServiceEndpoint(name: "Test", host: "example.com", port: 8080)
        XCTAssertEqual(ep.port, 8080)
    }

    // MARK: - ConnectionStatus
    func testConnectionStatus_connected() {
        if case .connected = ConnectionStatus.connected {} else {
            XCTFail("Expected .connected")
        }
    }

    func testConnectionStatus_disconnected() {
        if case .disconnected = ConnectionStatus.disconnected {} else {
            XCTFail("Expected .disconnected")
        }
    }

    // MARK: - MonitorConstants
    func testMonitorConstants_connectionTimeout() {
        XCTAssertEqual(MonitorConstants.connectionTimeout, 1.5)
    }

    func testMonitorConstants_defaultIntervals() {
        XCTAssertEqual(MonitorConstants.defaultLatencyInterval, 1.0)
        XCTAssertEqual(MonitorConstants.defaultNetworkInterval, 1.0)
    }

    func testMonitorConstants_availableIntervals() {
        XCTAssertEqual(MonitorConstants.availableIntervals, [0.5, 1.0, 2.0, 5.0])
    }

    func testMonitorConstants_intervalLimits() {
        XCTAssertEqual(MonitorConstants.minInterval, 0.5)
        XCTAssertEqual(MonitorConstants.maxInterval, 60.0)
    }

    func testMonitorConstants_queueLabels() {
        XCTAssertEqual(MonitorConstants.latencyQueueLabel, "com.imoni.latency")
        XCTAssertEqual(MonitorConstants.networkQueueLabel, "com.imoni.network")
    }

    func testMonitorConstants_maxReasonableSpeed() {
        XCTAssertEqual(MonitorConstants.maxReasonableSpeed, 1000.0)
    }

    // MARK: - DisplayMode
    func testDisplayMode_allCases() {
        let cases = DisplayMode.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.serviceLatency))
        XCTAssertTrue(cases.contains(.networkSpeed))
        XCTAssertTrue(cases.contains(.combined))
    }

    func testDisplayMode_rawValues() {
        XCTAssertEqual(DisplayMode.serviceLatency.rawValue, "Service")
        XCTAssertEqual(DisplayMode.networkSpeed.rawValue, "Network")
        XCTAssertEqual(DisplayMode.combined.rawValue, "Combined")
    }

    func testDisplayMode_displayNames() {
        XCTAssertEqual(DisplayMode.serviceLatency.displayName, "TCP Latency")
        XCTAssertEqual(DisplayMode.networkSpeed.displayName, "Network")
        XCTAssertEqual(DisplayMode.combined.displayName, "Combined")
    }

    func testDisplayMode_fromRawValue() {
        XCTAssertEqual(DisplayMode(rawValue: "Service"), .serviceLatency)
        XCTAssertEqual(DisplayMode(rawValue: "Network"), .networkSpeed)
        XCTAssertEqual(DisplayMode(rawValue: "Combined"), .combined)
    }

    func testDisplayMode_unknownRawValue() {
        XCTAssertNil(DisplayMode(rawValue: "Unknown"))
    }

    // MARK: - ServiceCategory
    func testServiceCategory_allCases() {
        let cases = ServiceCategory.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.aiServices))
        XCTAssertTrue(cases.contains(.ideServices))
        XCTAssertTrue(cases.contains(.development))
        XCTAssertTrue(cases.contains(.network))
    }

    func testServiceCategory_displayName() {
        XCTAssertEqual(ServiceCategory.aiServices.displayName, "AI Services")
        XCTAssertEqual(ServiceCategory.ideServices.displayName, "IDE Services")
        XCTAssertEqual(ServiceCategory.development.displayName, "Development")
        XCTAssertEqual(ServiceCategory.network.displayName, "Network")
    }
}
