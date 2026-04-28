import XCTest
@testable import iMoni

final class MonitorLatencyTests: XCTestCase {
    var monitor: MonitorLatency!
    let testEndpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 443)

    override func setUp() {
        super.setUp()
        monitor = MonitorLatency(queueLabel: MonitorConstants.latencyQueueLabel, interval: MonitorConstants.defaultLatencyInterval)
    }

    override func tearDown() {
        monitor.cleanup()
        super.tearDown()
    }

    func testInit_setsInitialState() {
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testStartMonitoring_setsIsMonitoringTrue() {
        monitor.startMonitoring(testEndpoint)
        XCTAssertTrue(monitor.isMonitoring)
        monitor.stopMonitoring()
    }

    func testStopMonitoring_setsIsMonitoringFalse() {
        monitor.startMonitoring(testEndpoint)
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testCleanup_resetsState() {
        monitor.startMonitoring(testEndpoint)
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
        monitor.startMonitoring(testEndpoint)
        let firstState = monitor.isMonitoring
        monitor.startMonitoring(testEndpoint)
        XCTAssertEqual(monitor.isMonitoring, firstState)
        monitor.stopMonitoring()
    }

    func testDoubleStop_hasNoEffect() {
        monitor.startMonitoring(testEndpoint)
        monitor.stopMonitoring()
        let firstState = monitor.isMonitoring
        monitor.stopMonitoring()
        XCTAssertEqual(monitor.isMonitoring, firstState)
    }

    func testDeinit_cleansUpResources() {
        var m: MonitorLatency? = MonitorLatency(queueLabel: "com.imoni.test.deinit", interval: 1.0)
        m?.startMonitoring(testEndpoint)
        m = nil
    }
}
