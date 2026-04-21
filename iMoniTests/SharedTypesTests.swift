//
//  SharedTypesTests.swift
//  iMoniTests
//
//  测试共享类型
//

import XCTest
@testable import iMoni

final class SharedTypesTests: XCTestCase {

    // MARK: - ServiceEndpoint 测试

    func testServiceEndpoint_defaultPort() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com")
        XCTAssertEqual(endpoint.name, "Test")
        XCTAssertEqual(endpoint.host, "example.com")
        XCTAssertEqual(endpoint.port, 443) // 默认端口
    }

    func testServiceEndpoint_customPort() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 8080)
        XCTAssertEqual(endpoint.port, 8080)
    }

    // MARK: - ConnectionStatus 测试

    func testConnectionStatus_connected() {
        let status = ConnectionStatus.connected
        // 验证枚举成员存在
        if case .connected = status {
            // success
        } else {
            XCTFail("Expected .connected case")
        }
    }

    func testConnectionStatus_disconnected() {
        let status = ConnectionStatus.disconnected
        if case .disconnected = status {
            // success
        } else {
            XCTFail("Expected .disconnected case")
        }
    }

    // MARK: - MonitorConstants 测试

    func testMonitorConstants_connectionTimeout() {
        XCTAssertEqual(MonitorConstants.connectionTimeout, 0.5)
    }

    func testMonitorConstants_defaultIntervals() {
        XCTAssertEqual(MonitorConstants.defaultLatencyInterval, 0.5)
        XCTAssertEqual(MonitorConstants.defaultNetworkInterval, 0.1)
    }

    func testMonitorConstants_availableIntervals() {
        let expectedIntervals: [TimeInterval] = [0.1, 0.5, 1.0, 2.0, 5.0]
        XCTAssertEqual(MonitorConstants.availableIntervals, expectedIntervals)
    }

    func testMonitorConstants_intervalLimits() {
        XCTAssertEqual(MonitorConstants.minInterval, 0.1)
        XCTAssertEqual(MonitorConstants.maxInterval, 10.0)
    }

    func testMonitorConstants_queueLabels() {
        XCTAssertEqual(MonitorConstants.latencyQueueLabel, "com.imoni.latency")
        XCTAssertEqual(MonitorConstants.networkQueueLabel, "com.imoni.network")
    }

    func testMonitorConstants_maxReasonableSpeed() {
        XCTAssertEqual(MonitorConstants.maxReasonableSpeed, 1000.0)
    }

    // MARK: - DisplayMode 测试

    func testDisplayMode_allCases() {
        let allCases = DisplayMode.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.serviceLatency))
        XCTAssertTrue(allCases.contains(.networkSpeed))
    }

    func testDisplayMode_rawValues() {
        XCTAssertEqual(DisplayMode.serviceLatency.rawValue, "Service")
        XCTAssertEqual(DisplayMode.networkSpeed.rawValue, "Network")
    }

    func testDisplayMode_fromRawValue() {
        XCTAssertEqual(DisplayMode(rawValue: "Service"), .serviceLatency)
        XCTAssertEqual(DisplayMode(rawValue: "Network"), .networkSpeed)
    }

    func testDisplayMode_unknownRawValue() {
        XCTAssertNil(DisplayMode(rawValue: "Unknown"))
    }

    // MARK: - ServiceCategory 测试

    func testServiceCategory_allCases() {
        let allCases = ServiceCategory.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.aiServices))
        XCTAssertTrue(allCases.contains(.ideServices))
        XCTAssertTrue(allCases.contains(.development))
        XCTAssertTrue(allCases.contains(.network))
    }

    func testServiceCategory_displayName() {
        XCTAssertEqual(ServiceCategory.aiServices.displayName, "AI Services")
        XCTAssertEqual(ServiceCategory.ideServices.displayName, "IDE Services")
        XCTAssertEqual(ServiceCategory.development.displayName, "Development")
        XCTAssertEqual(ServiceCategory.network.displayName, "Network")
    }
}
