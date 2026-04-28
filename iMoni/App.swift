import SwiftUI

@main
struct iMoniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarController?
    private var sleepObservers: [NSObjectProtocol] = []
    private var observersRegistered = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarManager = MenuBarController()
        registerSleepObservers()
    }

    deinit {
        unregisterSleepObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager?.cleanup()
        menuBarManager = nil
        unregisterSleepObservers()
    }

    private func registerSleepObservers() {
        guard !observersRegistered else { return }
        let nc = NSWorkspace.shared.notificationCenter

        let willSleep = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuBarManager?.suspend()
        }

        let didWake = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuBarManager?.resumeAfterWake()
        }

        sleepObservers.append(contentsOf: [willSleep, didWake])
        observersRegistered = true
    }

    private func unregisterSleepObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in sleepObservers {
            nc.removeObserver(observer)
        }
        sleepObservers.removeAll()
        observersRegistered = false
    }
}
