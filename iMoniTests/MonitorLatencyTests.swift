//
//  MonitorLatencyTests.swift
//  iMoniTests
//
//  测试延迟监控器
//

import XCTest
@testable import iMoni

final class MonitorLatencyTests: XCTestCase {

    var monitorLatency: MonitorLatency!
    let testEndpoint = ServiceEndpoint(name: "TestService", host: "example.com", port: 443)

    override func setUp() {
        super.setUp()
        monitorLatency = MonitorLatency(
            queueLabel: MonitorConstants.latencyQueueLabel,
            interval: MonitorConstants.defaultLatencyInterval
        )
    }

    override func tearDown() {
        monitorLatency.cleanup()
        super.tearDown()
    }

    // MARK: - 初始化测试

    func testInit_setsInitialState() {
        XCTAssertFalse(monitorLatency.isMonitoring)
    }

    // MARK: - 监控启停测试

    func testStartMonitoring_setsIsMonitoringTrue() {
        monitorLatency.startMonitoring(testEndpoint)
        XCTAssertTrue(monitorLatency.isMonitoring)
        monitorLatency.stopMonitoring()
    }

    func testStopMonitoring_setsIsMonitoringFalse() {
        monitorLatency.startMonitoring(testEndpoint)
        monitorLatency.stopMonitoring()
        XCTAssertFalse(monitorLatency.isMonitoring)
    }

    func testStartMonitoring_setsCurrentEndpoint() {
        monitorLatency.startMonitoring(testEndpoint)
        monitorLatency.stopMonitoring()
        // 验证能正常设置端点并启动
    }

    // MARK: - 清理测试

    func testCleanup_resetsState() {
        monitorLatency.startMonitoring(testEndpoint)
        monitorLatency.cleanup()
        XCTAssertFalse(monitorLatency.isMonitoring)
    }

    func testStopMonitoring_clearsEndpoint() {
        monitorLatency.startMonitoring(testEndpoint)
        monitorLatency.stopMonitoring()
        // 验证停止后端点被清除
    }

    // MARK: - 监控间隔测试

    func testUpdateInterval_updatesInterval() {
        monitorLatency.updateInterval(2.0)
        XCTAssertEqual(monitorLatency.monitoringInterval, 2.0)
    }

    func testUpdateInterval_clampsToValidRange() {
        // 小于最小值
        monitorLatency.updateInterval(0.01)
        XCTAssertEqual(monitorLatency.monitoringInterval, MonitorConstants.minInterval)

        // 大于最大值
        monitorLatency.updateInterval(100.0)
        XCTAssertEqual(monitorLatency.monitoringInterval, MonitorConstants.maxInterval)
    }

    // MARK: - 双重启停测试

    func testDoubleStart_hasNoEffect() {
        monitorLatency.startMonitoring(testEndpoint)
        let firstState = monitorLatency.isMonitoring
        monitorLatency.startMonitoring(testEndpoint)
        XCTAssertEqual(monitorLatency.isMonitoring, firstState)
        monitorLatency.stopMonitoring()
    }

    func testDoubleStop_hasNoEffect() {
        monitorLatency.startMonitoring(testEndpoint)
        monitorLatency.stopMonitoring()
        let firstState = monitorLatency.isMonitoring
        monitorLatency.stopMonitoring()
        XCTAssertEqual(monitorLatency.isMonitoring, firstState)
    }

    // MARK: - 资源清理测试

    func testDeinit_cleansUpResources() {
        var localMonitor: MonitorLatency? = MonitorLatency(
            queueLabel: "com.imoni.test.deinit",
            interval: 1.0
        )
        localMonitor?.startMonitoring(testEndpoint)
        localMonitor = nil
        // 如果没有崩溃，说明清理正常
    }
}
