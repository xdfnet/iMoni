import XCTest
@testable import iMoni

final class MenuBarControllerTests: XCTestCase {
    var controller: MenuBarController!

    override func setUp() {
        super.setUp()
        controller = MenuBarController()
    }

    override func tearDown() {
        controller.cleanup()
        super.tearDown()
    }

    func testInit_createsController() {
        XCTAssertNotNil(controller)
    }

    func testCleanup_releasesResources() {
        controller.cleanup()
    }

    func testSuspend_stopsMonitoring() {
        controller.suspend()
    }

    func testResumeAfterWake_recreatesStatusBar() {
        controller.suspend()
        controller.resumeAfterWake()
    }
}
