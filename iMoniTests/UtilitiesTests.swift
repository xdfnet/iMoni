//
//  UtilitiesTests.swift
//  iMoniTests
//
//  测试工具类函数
//

import XCTest
@testable import iMoni

final class UtilitiesTests: XCTestCase {

    // MARK: - 格式化工具测试

    func testFormatLatency_convertsSecondsToMilliseconds() {
        // 0.15秒 = 150ms
        let result = Utilities.formatLatency(0.15)
        XCTAssertEqual(result, "150ms")
    }

    func testFormatLatency_zeroLatency() {
        let result = Utilities.formatLatency(0.0)
        XCTAssertEqual(result, "0ms")
    }

    func testFormatLatency_largeLatency() {
        // 10秒 = 10000ms
        let result = Utilities.formatLatency(10.0)
        XCTAssertEqual(result, "10000ms")
    }

    func testFormatSpeed_formatsWithTwoDecimalPlaces() {
        // 12.345 MB/s 应该格式化为 12.35MB/s
        let result = Utilities.formatSpeed(12.345)
        XCTAssertEqual(result, "12.35MB/s")
    }

    func testFormatSpeed_zeroSpeed() {
        let result = Utilities.formatSpeed(0.0)
        XCTAssertEqual(result, "0.00MB/s")
    }

    func testFormatSpeed_wholeNumber() {
        let result = Utilities.formatSpeed(100.0)
        XCTAssertEqual(result, "100.00MB/s")
    }

    // MARK: - 数值工具测试

    func testClamp_returnsMinWhenBelow() {
        let result = Utilities.clamp(5, min: 10, max: 20)
        XCTAssertEqual(result, 10)
    }

    func testClamp_returnsMaxWhenAbove() {
        let result = Utilities.clamp(25, min: 10, max: 20)
        XCTAssertEqual(result, 20)
    }

    func testClamp_returnsValueWhenInRange() {
        let result = Utilities.clamp(15, min: 10, max: 20)
        XCTAssertEqual(result, 15)
    }

    func testClamp_withDoubleValues() {
        let result = Utilities.clamp(0.5, min: 0.0, max: 1.0)
        XCTAssertEqual(result, 0.5)
    }

    func testClamp_withDoubleValuesBelowMin() {
        let result = Utilities.clamp(-0.5, min: 0.0, max: 1.0)
        XCTAssertEqual(result, 0.0)
    }

    func testClamp_withDoubleValuesAboveMax() {
        let result = Utilities.clamp(1.5, min: 0.0, max: 1.0)
        XCTAssertEqual(result, 1.0)
    }

    func testSafeInt_convertsInt() {
        let result = Utilities.safeInt(42, defaultValue: -1)
        XCTAssertEqual(result, 42)
    }

    func testSafeInt_convertsString() {
        let result = Utilities.safeInt("123", defaultValue: -1)
        XCTAssertEqual(result, 123)
    }

    func testSafeInt_convertsDouble() {
        let result = Utilities.safeInt(99.7, defaultValue: -1)
        XCTAssertEqual(result, 99)
    }

    func testSafeInt_returnsDefaultOnFailure() {
        let result = Utilities.safeInt("not a number", defaultValue: 999)
        XCTAssertEqual(result, 999)
    }

    func testSafeInt_returnsDefaultWhenNil() {
        let result = Utilities.safeInt(nil, defaultValue: 42)
        XCTAssertEqual(result, 42)
    }

    func testSafeInt_convertsNegativeInt() {
        let result = Utilities.safeInt(-10, defaultValue: 0)
        XCTAssertEqual(result, -10)
    }

    func testSafeInt_convertsNegativeString() {
        let result = Utilities.safeInt("-99", defaultValue: 0)
        XCTAssertEqual(result, -99)
    }

    // MARK: - 验证工具测试

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
        // 端口 65535 是有效边界值
        let endpoint = ServiceEndpoint(name: "Test", host: "example.com", port: 65535)
        XCTAssertTrue(Utilities.validateServiceEndpoint(endpoint))
    }

    // MARK: - 时间工具测试

    func testCurrentTimestamp_returnsValidTimestamp() {
        let timestamp1 = Utilities.currentTimestamp()
        let timestamp2 = Utilities.currentTimestamp()
        // 两次调用应该在极短时间内返回不同的值
        XCTAssertGreaterThanOrEqual(timestamp2, timestamp1)
    }

    func testTimeDifference_calculatesCorrectDifference() {
        let startTime = Utilities.currentTimestamp()
        // timeDifference 计算的是 startTime 到当前时间的时间差
        // 因为 startTime 是刚才获取的，所以差值应该接近 0
        let difference = Utilities.timeDifference(from: startTime)
        // 允许浮点数精度误差，差值应该很小（刚获取时间戳后）
        XCTAssertLessThan(difference, 0.01)
    }

    // MARK: - 线程安全工具测试

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
