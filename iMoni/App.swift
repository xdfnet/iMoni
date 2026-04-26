//
//  App.swift
//  iMoni
//
//  Created by iMoni Team
//  Copyright © 2025 iMoni App. All rights reserved.
//
//  应用入口文件：负责应用生命周期管理
//
//  功能说明：
//  - 使用 SwiftUI 的 @main + App 协议作为入口
//  - 通过 AppDelegate 启动菜单栏管理器 MenuBarController
//  - 不创建主窗口，仅提供菜单栏应用形态
//

import SwiftUI

// MARK: - 主应用结构

@main
struct iMoniApp: App {

    // MARK: - 属性

    /// 应用代理适配器
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - 场景构建

    var body: some Scene {
        // 纯菜单栏应用，使用 Settings 场景但不需要实际窗口
        Settings {
            EmptyView()
        }
    }
}

// MARK: - 应用代理

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - 属性
    
    /// 菜单栏管理器实例
    private var menuBarManager: MenuBarController?
    
    /// 系统睡眠/唤醒观察者
    private var sleepObservers: [NSObjectProtocol] = []
    
    /// 标记是否已注册观察者
    private var observersRegistered = false
    
    // MARK: - 应用生命周期
    
    /// 应用启动完成回调
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，仅保留菜单栏图标
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化菜单栏管理器（创建状态栏图标与菜单）
        menuBarManager = MenuBarController()

        // 注册系统睡眠/唤醒观察者（仅注册一次）
        registerSleepObservers()
    }
    
    deinit {
        // 确保观察者被移除，防止内存泄漏
        unregisterSleepObservers()
    }
    
    /// 应用即将退出回调
    func applicationWillTerminate(_ notification: Notification) {
        // 退出前清理资源（停止定时器、释放对象）
        menuBarManager?.cleanup()
        menuBarManager = nil

        // 移除通知监听
        unregisterSleepObservers()
    }
    
    // MARK: - 私有方法
    
    /// 注册系统睡眠/唤醒观察者
    private func registerSleepObservers() {
        // 防止重复注册
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
    
    /// 移除系统睡眠/唤醒观察者
    private func unregisterSleepObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in sleepObservers {
            nc.removeObserver(observer)
        }
        sleepObservers.removeAll()
        observersRegistered = false
    }
}
