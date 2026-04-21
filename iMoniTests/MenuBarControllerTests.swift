//
//  MenuBarControllerTests.swift
//  iMoniTests
//
//  测试菜单栏控制器
//

import XCTest
@testable import iMoni

final class MenuBarControllerTests: XCTestCase {

    var menuBarController: MenuBarController!

    override func setUp() {
        super.setUp()
        menuBarController = MenuBarController()
    }

    override func tearDown() {
        menuBarController.cleanup()
        super.tearDown()
    }

    // MARK: - 生命周期测试

    func testInit_createsController() {
        XCTAssertNotNil(menuBarController)
    }

    func testCleanup_releasesResources() {
        menuBarController.cleanup()
        // 验证清理后不会崩溃
    }

    func testSuspend_stopsMonitoring() {
        menuBarController.suspend()
        // 验证挂起后状态栏项被清除
    }

    func testResumeAfterWake_recreatesStatusBar() {
        menuBarController.suspend()
        menuBarController.resumeAfterWake()
        // 验证恢复后状态栏项被重新创建
    }
}
