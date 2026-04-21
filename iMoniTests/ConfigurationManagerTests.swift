//
//  ConfigurationManagerTests.swift
//  iMoniTests
//
//  测试配置管理器
//

import XCTest
@testable import iMoni

final class ConfigurationManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 重置配置到默认值
        ConfigurationManager.shared.resetToDefaults()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - 显示模式测试

    func testSetDisplayMode_triggersChangeNotification() {
        let configurationManager = ConfigurationManager.shared
        let expectation = self.expectation(description: "configuration changed")
        configurationManager.onConfigurationChanged = {
            expectation.fulfill()
        }

        configurationManager.setDisplayMode(.networkSpeed)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - 监控间隔测试

    func testSetMonitoringInterval_clampsToMin() {
        let configurationManager = ConfigurationManager.shared
        // 小于最小值应该被限制到最小值
        configurationManager.setMonitoringInterval(0.01)
        // 等待异步操作完成
        Thread.sleep(forTimeInterval: 0.2)
        let interval = configurationManager.getMonitoringInterval()
        XCTAssertEqual(interval, MonitorConstants.minInterval)
    }

    func testSetMonitoringInterval_clampsToMax() {
        let configurationManager = ConfigurationManager.shared
        // 大于最大值应该被限制到最大值
        configurationManager.setMonitoringInterval(100.0)
        // 等待异步操作完成
        Thread.sleep(forTimeInterval: 0.2)
        let interval = configurationManager.getMonitoringInterval()
        XCTAssertEqual(interval, MonitorConstants.maxInterval)
    }

    func testGetMonitoringInterval_defaultValue() {
        let configurationManager = ConfigurationManager.shared
        // 默认值应该是 defaultUserInterval
        let interval = configurationManager.getMonitoringInterval()
        XCTAssertEqual(interval, MonitorConstants.defaultUserInterval)
    }

    // MARK: - 通知设置测试

    func testSetEnableNotifications_triggersChangeNotification() {
        let configurationManager = ConfigurationManager.shared
        let expectation = self.expectation(description: "configuration changed")
        configurationManager.onConfigurationChanged = {
            expectation.fulfill()
        }

        configurationManager.setEnableNotifications(false)
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - 导出导入测试

    func testExportConfiguration_returnsValidData() {
        let configurationManager = ConfigurationManager.shared
        let data = configurationManager.exportConfiguration()
        XCTAssertNotNil(data)
    }

    func testImportConfiguration_invalidData() {
        let configurationManager = ConfigurationManager.shared
        let invalidData = "not valid json".data(using: .utf8)!
        let success = configurationManager.importConfiguration(invalidData)
        XCTAssertFalse(success)
    }

    // MARK: - 重置测试

    func testResetToDefaults_triggersChangeNotification() {
        let configurationManager = ConfigurationManager.shared
        let expectation = self.expectation(description: "configuration changed")
        configurationManager.onConfigurationChanged = {
            expectation.fulfill()
        }

        configurationManager.resetToDefaults()
        waitForExpectations(timeout: 2.0)
    }
}
