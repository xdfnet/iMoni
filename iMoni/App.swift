import SwiftUI

@main
struct iMoniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarManager = MenuBarController()
        registerSleepObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager?.cleanup()
        menuBarManager = nil
        let nc = NSWorkspace.shared.notificationCenter
        nc.removeObserver(self)
    }

    private func registerSleepObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.menuBarManager?.suspend()
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.menuBarManager?.resumeAfterWake()
        }
    }
}
