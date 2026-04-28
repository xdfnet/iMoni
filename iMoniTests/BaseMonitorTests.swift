import XCTest
@testable import iMoni

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

    func testInit_setsInitialState() {
        XCTAssertFalse(monitor.isMonitoring)
        XCTAssertEqual(monitor.monitoringInterval, 1.0)
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
        var m: TestableMonitor? = TestableMonitor(queueLabel: "com.imoni.test.deinit", interval: 1.0)
        m?.startMonitoring()
        m = nil
    }

    func testUpdateInterval_clampsToValidRange() {
        monitor.updateInterval(0.01)
        XCTAssertEqual(monitor.monitoringInterval, MonitorConstants.minInterval)
        monitor.updateInterval(100.0)
        XCTAssertEqual(monitor.monitoringInterval, MonitorConstants.maxInterval)
    }

    func testUpdateInterval_acceptsValidValue() {
        monitor.updateInterval(2.0)
        XCTAssertEqual(monitor.monitoringInterval, 2.0)
    }

    func testUpdateInterval_doesNotRestartTimerWhenInactive() {
        monitor.startMonitoring()
        let countBefore = monitor.performMonitoringCallCount
        monitor.stopMonitoring()
        monitor.updateInterval(0.5)
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(monitor.performMonitoringCallCount, countBefore)
    }
}
