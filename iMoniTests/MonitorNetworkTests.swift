import XCTest
@testable import iMoni

final class MonitorNetworkTests: XCTestCase {
    var monitor: MonitorNetwork!

    override func setUp() {
        super.setUp()
        monitor = MonitorNetwork(queueLabel: MonitorConstants.networkQueueLabel, interval: MonitorConstants.defaultNetworkInterval)
    }

    override func tearDown() {
        monitor.cleanup()
        super.tearDown()
    }

    func testInit_setsInitialState() {
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testStartMonitoring_setsIsMonitoringTrue() {
        monitor.startMonitoring()
        XCTAssertTrue(monitor.isMonitoring)
    }

    func testStopMonitoring_setsIsMonitoringFalse() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testCleanup_resetsState() {
        monitor.startMonitoring()
        monitor.cleanup()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testUpdateInterval_updatesInterval() {
        monitor.updateInterval(2.0)
        XCTAssertEqual(monitor.monitoringInterval, 2.0)
    }

    func testUpdateInterval_clampsToMin() {
        monitor.updateInterval(0.01)
        XCTAssertEqual(monitor.monitoringInterval, MonitorConstants.minInterval)
    }

    func testUpdateInterval_clampsToMax() {
        monitor.updateInterval(100.0)
        XCTAssertEqual(monitor.monitoringInterval, MonitorConstants.maxInterval)
    }

    func testDoubleStart_hasNoEffect() {
        monitor.startMonitoring()
        let firstState = monitor.isMonitoring
        monitor.startMonitoring()
        XCTAssertEqual(monitor.isMonitoring, firstState)
    }

    func testDoubleStop_hasNoEffect() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        let firstState = monitor.isMonitoring
        monitor.stopMonitoring()
        XCTAssertEqual(monitor.isMonitoring, firstState)
    }

    func testDeinit_cleansUpResources() {
        var m: MonitorNetwork? = MonitorNetwork(queueLabel: "com.imoni.test.deinit", interval: 1.0)
        m?.startMonitoring()
        m = nil
    }
}
