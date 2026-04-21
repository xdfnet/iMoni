//
//  BaseMonitorTests.swift
//  iMoniTests
//
//  测试基础监控类
//

import XCTest
@testable import iMoni

// 可测试的 BaseMonitor 子类
final class TestableMonitor: BaseMonitor {
    var performMonitoringCallCount = 0
    var cleanupResourcesCallCount = 0

    override func performMonitoring() {
        performMonitoringCallCount += 1
    }

    override func cleanupResources() {
        cleanupResourcesCallCount += 1
    }
}

final class BaseMonitorTests: XCTestCase {

    var monitor: TestableMonitor!

    override func setUp() {
        super.setUp()
        monitor = TestableMonitor(queueLabel: "com.imoni.test", interval: 1.0)
    }

    override func tearDown() {
        monitor.cleanup()
        super.tearDown()
    }

    // MARK: - 初始化测试

    func testInit_setsInitialState() {
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.monitoringInterval, 1.0)
    }

    // MARK: - 监控启停测试

    func testStartMonitoring_setsIsMonitoringTrue() {
        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
    }

    func testStopMonitoring_setsIsMonitoringFalse() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    // MARK: - 双重启停测试

    func testDoubleStart_hasNoEffect() {
        monitor.startMonitoring()
        let firstStartState = monitor.isMonitoring

        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
        XCTAssertEqual(monitor.isMonitoring, firstStartState)
    }

    func testDoubleStop_hasNoEffect() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        let firstStopState = monitor.isMonitoring

        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.isMonitoring, firstStopState)
    }

    // MARK: - 清理测试

    func testCleanup_resetsState() {
        monitor.startMonitoring()
        monitor.cleanup()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testCleanup_callsCleanupResources() {
        monitor.startMonitoring()
        let initialCount = monitor.cleanupResourcesCallCount
        monitor.cleanup()
        XCTAssertGreaterThan(monitor.cleanupResourcesCallCount, initialCount)
    }

    func testDeinit_cleansUpResources() {
        var localMonitor: TestableMonitor? = TestableMonitor(queueLabel: "com.imoni.test.deinit", interval: 1.0)
        localMonitor?.startMonitoring()
        localMonitor = nil
        // 如果没有崩溃，说明清理正常
    }

    // MARK: - 监控间隔测试

    func testUpdateInterval_clampsToValidRange() {
        // 测试小于最小值
        monitor.updateInterval(0.01)
        XCTAssertEqual(monitor.monitoringInterval, MonitorConstants.minInterval)

        // 测试大于最大值
        monitor.updateInterval(100.0)
        XCTAssertEqual(monitor.monitoringInterval, MonitorConstants.maxInterval)
    }

    func testUpdateInterval_acceptsValidValue() {
        monitor.updateInterval(2.0)
        XCTAssertEqual(monitor.monitoringInterval, 2.0)
    }

    func testUpdateInterval_doesNotRestartTimerWhenInactive() {
        monitor.startMonitoring()
        let countBeforeUpdate = monitor.performMonitoringCallCount
        monitor.stopMonitoring()

        // 更新间隔时监控已停止
        monitor.updateInterval(0.5)

        // 短暂等待
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(monitor.performMonitoringCallCount, countBeforeUpdate)
    }
}
