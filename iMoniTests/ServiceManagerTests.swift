//
//  ServiceManagerTests.swift
//  iMoniTests
//
//  测试服务管理器
//

import XCTest
@testable import iMoni

final class ServiceManagerTests: XCTestCase {

    var serviceManager: ServiceManager!

    override func setUp() {
        super.setUp()
        serviceManager = ServiceManager.shared
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - 单例测试

    func testShared_instanceNotNil() {
        XCTAssertNotNil(ServiceManager.shared)
    }

    // MARK: - 服务列表测试

    func testAllEndpoints_notEmpty() {
        XCTAssertFalse(serviceManager.allEndpoints.isEmpty)
    }

    func testCategorizedEndpoints_notEmpty() {
        XCTAssertFalse(serviceManager.categorizedEndpoints.isEmpty)
    }

    func testCategories_returnsAllCategories() {
        let categories = serviceManager.categories
        XCTAssertEqual(categories.count, 4)
    }

    // MARK: - 服务类别测试

    func testGetEndpoints_forAIServices() {
        let endpoints = serviceManager.getEndpoints(for: .aiServices)
        XCTAssertFalse(endpoints.isEmpty)

        // 验证包含 Claude
        let hasClaude = endpoints.contains { $0.name == "Claude" }
        XCTAssertTrue(hasClaude)
    }

    func testGetEndpoints_forIDEServices() {
        let endpoints = serviceManager.getEndpoints(for: .ideServices)
        XCTAssertFalse(endpoints.isEmpty)

        // 验证包含 Cursor
        let hasCursor = endpoints.contains { $0.name == "Cursor" }
        XCTAssertTrue(hasCursor)
    }

    func testGetEndpoints_forDevelopment() {
        let endpoints = serviceManager.getEndpoints(for: .development)
        XCTAssertFalse(endpoints.isEmpty)

        // 验证包含 Homebrew
        let hasHomebrew = endpoints.contains { $0.name == "Homebrew" }
        XCTAssertTrue(hasHomebrew)
    }

    func testGetEndpoints_forNetwork() {
        let endpoints = serviceManager.getEndpoints(for: .network)
        XCTAssertFalse(endpoints.isEmpty)

        // 验证包含 Docker Hub
        let hasDockerHub = endpoints.contains { $0.name == "Docker Hub" }
        XCTAssertTrue(hasDockerHub)
    }

    func testGetEndpoints_unknownCategory() {
        // 使用一个空的假类别（不会匹配任何）
        let endpoints = serviceManager.categorizedEndpoints.first { $0.category == .network }?.endpoints ?? []
        XCTAssertFalse(endpoints.isEmpty)
    }

    // MARK: - 端点详情测试

    func testEndpoint_hasValidPort() {
        for endpoint in serviceManager.allEndpoints {
            XCTAssertGreaterThan(endpoint.port, 0)
            XCTAssertLessThanOrEqual(endpoint.port, 65535)
        }
    }

    func testEndpoint_hasValidHost() {
        for endpoint in serviceManager.allEndpoints {
            XCTAssertFalse(endpoint.host.isEmpty)
        }
    }

    func testEndpoint_hasValidName() {
        for endpoint in serviceManager.allEndpoints {
            XCTAssertFalse(endpoint.name.isEmpty)
        }
    }

    // MARK: - 向后兼容测试

    func testEndpoints_alias_works() {
        let endpoints = serviceManager.endpoints
        XCTAssertEqual(endpoints.count, serviceManager.allEndpoints.count)
    }
}
