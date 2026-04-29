import XCTest
@testable import iMoni

final class UtilitiesTests: XCTestCase {
    // MARK: - Formatting
    func testFormatLatency_convertsSecondsToMilliseconds() {
        XCTAssertEqual(Utilities.formatLatency(0.15), "150ms")
    }

    func testFormatLatency_zeroLatency() {
        XCTAssertEqual(Utilities.formatLatency(0.0), "0ms")
    }

    func testFormatLatency_largeLatency() {
        XCTAssertEqual(Utilities.formatLatency(10.0), "10000ms")
    }

    func testFormatSpeed_formatsMegabytesWithTwoDecimalPlaces() {
        XCTAssertEqual(Utilities.formatSpeed(12.345), "12.35MB/s")
    }

    func testFormatSpeed_zeroSpeed() {
        XCTAssertEqual(Utilities.formatSpeed(0.0), "0B/s")
    }

    func testFormatSpeed_formatsBytes() {
        XCTAssertEqual(Utilities.formatSpeed(0.000512), "512B/s")
    }

    func testFormatSpeed_formatsKilobytes() {
        XCTAssertEqual(Utilities.formatSpeed(0.012345), "12.3KB/s")
    }

    func testFormatSpeed_formatsGigabytes() {
        XCTAssertEqual(Utilities.formatSpeed(1234.0), "1.23GB/s")
    }

    func testFormatSpeed_clampsNegativeSpeedToZero() {
        XCTAssertEqual(Utilities.formatSpeed(-1.0), "0B/s")
    }

    // MARK: - Numeric
    func testClamp_returnsMinWhenBelow() {
        XCTAssertEqual(Utilities.clamp(5, min: 10, max: 20), 10)
    }

    func testClamp_returnsMaxWhenAbove() {
        XCTAssertEqual(Utilities.clamp(25, min: 10, max: 20), 20)
    }

    func testClamp_returnsValueWhenInRange() {
        XCTAssertEqual(Utilities.clamp(15, min: 10, max: 20), 15)
    }

    func testClamp_withDoubleValues() {
        XCTAssertEqual(Utilities.clamp(0.5, min: 0.0, max: 1.0), 0.5)
    }

    func testClamp_withDoubleValuesBelowMin() {
        XCTAssertEqual(Utilities.clamp(-0.5, min: 0.0, max: 1.0), 0.0)
    }

    func testClamp_withDoubleValuesAboveMax() {
        XCTAssertEqual(Utilities.clamp(1.5, min: 0.0, max: 1.0), 1.0)
    }

    func testSafeInt_convertsInt() {
        XCTAssertEqual(Utilities.safeInt(42, defaultValue: -1), 42)
    }

    func testSafeInt_convertsString() {
        XCTAssertEqual(Utilities.safeInt("123", defaultValue: -1), 123)
    }

    func testSafeInt_convertsDouble() {
        XCTAssertEqual(Utilities.safeInt(99.7, defaultValue: -1), 99)
    }

    func testSafeInt_returnsDefaultOnFailure() {
        XCTAssertEqual(Utilities.safeInt("not a number", defaultValue: 999), 999)
    }

    func testSafeInt_returnsDefaultWhenNil() {
        XCTAssertEqual(Utilities.safeInt(nil, defaultValue: 42), 42)
    }

    func testSafeInt_convertsNegativeInt() {
        XCTAssertEqual(Utilities.safeInt(-10, defaultValue: 0), -10)
    }

    func testSafeInt_convertsNegativeString() {
        XCTAssertEqual(Utilities.safeInt("-99", defaultValue: 0), -99)
    }

    // MARK: - Validation
    func testValidateServiceEndpoint_validEndpoint() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 443)
        XCTAssertTrue(Utilities.validateServiceEndpoint(endpoint))
    }

    func testValidateServiceEndpoint_emptyName() {
        let endpoint = ServiceEndpoint(name: "", host: "example.com", port: 443)
        XCTAssertFalse(Utilities.validateServiceEndpoint(endpoint))
    }

    func testValidateServiceEndpoint_emptyHost() {
        let endpoint = ServiceEndpoint(name: "Test", host: "", port: 443)
        XCTAssertFalse(Utilities.validateServiceEndpoint(endpoint))
    }

    func testValidateServiceEndpoint_invalidPortZero() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 0)
        XCTAssertFalse(Utilities.validateServiceEndpoint(endpoint))
    }

    func testValidateServiceEndpoint_invalidPortNegative() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: -1)
        XCTAssertFalse(Utilities.validateServiceEndpoint(endpoint))
    }

    func testValidateServiceEndpoint_invalidPortTooHigh() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 65536)
        XCTAssertFalse(Utilities.validateServiceEndpoint(endpoint))
    }

    func testValidateServiceEndpoint_validPortBoundary() {
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 65535)
        XCTAssertTrue(Utilities.validateServiceEndpoint(endpoint))
    }

    // MARK: - Time
    func testCurrentTimestamp_returnsValidTimestamp() {
        let t1 = Utilities.currentTimestamp()
        let t2 = Utilities.currentTimestamp()
        XCTAssertGreaterThanOrEqual(t2, t1)
    }

    func testTimeDifference_calculatesCorrectDifference() {
        let start = Utilities.currentTimestamp()
        let diff = Utilities.timeDifference(from: start)
        XCTAssertLessThan(diff, 0.01)
    }

    // MARK: - Thread Safety
    func testSafeMainQueueCallback_executesOnMainThread() {
        let expectation = self.expectation(description: "callback executed")
        var executed = false
        Utilities.safeMainQueueCallback {
            executed = true
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(executed)
    }
}
