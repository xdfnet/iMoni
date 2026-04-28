import XCTest
@testable import iMoni

final class ServiceManagerTests: XCTestCase {
    let sm = ServiceManager.shared

    func testShared_instanceNotNil() {
        XCTAssertNotNil(ServiceManager.shared)
    }

    func testAllEndpoints_notEmpty() {
        XCTAssertFalse(sm.allEndpoints.isEmpty)
    }

    func testCategorizedEndpoints_notEmpty() {
        XCTAssertFalse(sm.categorizedEndpoints.isEmpty)
    }

    func testCategories_returnsAll() {
        XCTAssertEqual(sm.categories.count, 4)
    }

    func testGetEndpoints_forAIServices() {
        let endpoints = sm.getEndpoints(for: .aiServices)
        XCTAssertFalse(endpoints.isEmpty)
        XCTAssertTrue(endpoints.contains { $0.name == "Claude" })
    }

    func testGetEndpoints_forIDEServices() {
        let endpoints = sm.getEndpoints(for: .ideServices)
        XCTAssertFalse(endpoints.isEmpty)
        XCTAssertTrue(endpoints.contains { $0.name == "Cursor" })
    }

    func testGetEndpoints_forDevelopment() {
        let endpoints = sm.getEndpoints(for: .development)
        XCTAssertFalse(endpoints.isEmpty)
        XCTAssertTrue(endpoints.contains { $0.name == "Homebrew" })
    }

    func testGetEndpoints_forNetwork() {
        let endpoints = sm.getEndpoints(for: .network)
        XCTAssertFalse(endpoints.isEmpty)
        XCTAssertTrue(endpoints.contains { $0.name == "Docker Hub" })
    }

    func testAllEndpoints_haveValidPort() {
        for ep in sm.allEndpoints {
            XCTAssertGreaterThan(ep.port, 0)
            XCTAssertLessThanOrEqual(ep.port, 65535)
        }
    }

    func testAllEndpoints_haveNonEmptyHost() {
        for ep in sm.allEndpoints {
            XCTAssertFalse(ep.host.isEmpty)
        }
    }

    func testAllEndpoints_haveNonEmptyName() {
        for ep in sm.allEndpoints {
            XCTAssertFalse(ep.name.isEmpty)
        }
    }

    func testEndpointsAlias_matchesAllEndpoints() {
        XCTAssertEqual(sm.endpoints.count, sm.allEndpoints.count)
    }
}
