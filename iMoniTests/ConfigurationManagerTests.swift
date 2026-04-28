import XCTest
@testable import iMoni

final class ConfigurationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ConfigurationManager.shared.resetToDefaults()
    }

    func testSetDisplayMode_triggersChangeNotification() {
        let config = ConfigurationManager.shared
        let expectation = self.expectation(description: "configuration changed")
        config.onConfigurationChanged = { expectation.fulfill() }
        config.setDisplayMode(.networkSpeed)
        waitForExpectations(timeout: 2.0)
    }

    func testSetMonitoringInterval_clampsToMin() {
        let config = ConfigurationManager.shared
        config.setMonitoringInterval(0.01)
        XCTAssertEqual(config.getMonitoringInterval(), MonitorConstants.minInterval)
    }

    func testSetMonitoringInterval_clampsToMax() {
        let config = ConfigurationManager.shared
        config.setMonitoringInterval(100.0)
        XCTAssertEqual(config.getMonitoringInterval(), MonitorConstants.maxInterval)
    }

    func testGetMonitoringInterval_defaultValue() {
        let config = ConfigurationManager.shared
        XCTAssertEqual(config.getMonitoringInterval(), MonitorConstants.defaultUserInterval)
    }

    func testSetEnableNotifications_triggersChangeNotification() {
        let config = ConfigurationManager.shared
        let expectation = self.expectation(description: "configuration changed")
        config.onConfigurationChanged = { expectation.fulfill() }
        config.setEnableNotifications(false)
        waitForExpectations(timeout: 2.0)
    }

    func testExportConfiguration_returnsValidData() {
        XCTAssertNotNil(ConfigurationManager.shared.exportConfiguration())
    }

    func testImportConfiguration_invalidData() {
        let invalidData = "not valid json".data(using: .utf8)!
        XCTAssertFalse(ConfigurationManager.shared.importConfiguration(invalidData))
    }

    func testResetToDefaults_triggersChangeNotification() {
        let config = ConfigurationManager.shared
        let expectation = self.expectation(description: "configuration changed")
        config.onConfigurationChanged = { expectation.fulfill() }
        config.resetToDefaults()
        waitForExpectations(timeout: 2.0)
    }
}
