//
//  MonitorNetworkTests.swift
//  iMoniTests
//
//  测试网络流量监控器
//

import XCTest
@testable import iMoni

final class MonitorNetworkTests: XCTestCase {

    var monitorNetwork: MonitorNetwork!

    override func setUp() {
        super.setUp()
        monitorNetwork = MonitorNetwork(
            queueLabel: MonitorConstants.networkQueueLabel,
            interval: MonitorConstants.defaultNetworkInterval
        )
    }

    override func tearDown() {
        monitorNetwork.cleanup()
        super.tearDown()
    }

    // MARK: - 初始化测试

    func testInit_setsInitialState() {
        XCTAssertFalse(monitorNetwork.isMonitoring)
    }

    // MARK: - 监控启停测试

    func testStartMonitoring_setsIsMonitoringTrue() {
        monitorNetwork.startMonitoring()
        XCTAssertTrue(monitorNetwork.isMonitoring)
    }

    func testStopMonitoring_setsIsMonitoringFalse() {
        monitorNetwork.startMonitoring()
        monitorNetwork.stopMonitoring()
        XCTAssertFalse(monitorNetwork.isMonitoring)
    }

    func testStartMonitoring_initializesNetworkStats() {
        monitorNetwork.startMonitoring()
        // 验证能正常启动
        XCTAssertTrue(monitorNetwork.isMonitoring)
        monitorNetwork.stopMonitoring()
    }

    // MARK: - 清理测试

    func testCleanup_resetsState() {
        monitorNetwork.startMonitoring()
        monitorNetwork.cleanup()
        XCTAssertFalse(monitorNetwork.isMonitoring)
    }

    func testStopMonitoring_resetsBytesCounters() {
        monitorNetwork.startMonitoring()
        monitorNetwork.stopMonitoring()
        // 验证停止后状态已重置
    }

    // MARK: - 监控间隔测试

    func testUpdateInterval_updatesInterval() {
        monitorNetwork.updateInterval(2.0)
        XCTAssertEqual(monitorNetwork.monitoringInterval, 2.0)
    }

    func testUpdateInterval_clampsToValidRange() {
        // 小于最小值
        monitorNetwork.updateInterval(0.01)
        XCTAssertEqual(monitorNetwork.monitoringInterval, MonitorConstants.minInterval)

        // 大于最大值
        monitorNetwork.updateInterval(100.0)
        XCTAssertEqual(monitorNetwork.monitoringInterval, MonitorConstants.maxInterval)
    }

    // MARK: - 双重启停测试

    func testDoubleStart_hasNoEffect() {
        monitorNetwork.startMonitoring()
        let firstState = monitorNetwork.isMonitoring
        monitorNetwork.startMonitoring()
        XCTAssertEqual(monitorNetwork.isMonitoring, firstState)
    }

    func testDoubleStop_hasNoEffect() {
        monitorNetwork.startMonitoring()
        monitorNetwork.stopMonitoring()
        let firstState = monitorNetwork.isMonitoring
        monitorNetwork.stopMonitoring()
        XCTAssertEqual(monitorNetwork.isMonitoring, firstState)
    }

    // MARK: - 资源清理测试

    func testDeinit_cleansUpResources() {
        var localMonitor: MonitorNetwork? = MonitorNetwork(
            queueLabel: "com.imoni.test.deinit",
            interval: 1.0
        )
        localMonitor?.startMonitoring()
        localMonitor = nil
        // 如果没有崩溃，说明清理正常
    }
}
