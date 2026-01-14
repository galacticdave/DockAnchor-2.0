//
//  DockAnchorApp.swift
//  DockAnchor
//
//  Created for DockAnchor v2.0
//

import SwiftUI
import ServiceManagement
import Combine

// MARK: - Window Delegate (Hides App on Close)
class WindowHiderDelegate: NSObject, NSWindowDelegate {
    private var appSettings: AppSettings?
    
    func setup(appSettings: AppSettings) {
        self.appSettings = appSettings
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        // If hidden from dock, ensure we stay in accessory mode
        if appSettings?.hideFromDock == true {
            NSApp.setActivationPolicy(.accessory)
        }
        return false
    }
}

// MARK: - Main Application Entry
@main
struct DockAnchorApp: App {
    @StateObject private var appSettings = AppSettings()
    @StateObject private var dockMonitor = DockMonitor()
    @StateObject private var menuBarManager = MenuBarManager()
    
    @State private var hasPermissions = false
    @State private var timer: Timer?
    
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    private let windowHiderDelegate = WindowHiderDelegate()
    
    var body: some Scene {
        WindowGroup {
            if hasPermissions {
                ContentView()
                    .environmentObject(appSettings)
                    .environmentObject(dockMonitor)
                    .onAppear(perform: setupMainApp)
            } else {
                OnboardingView(hasPermissions: $hasPermissions)
                    .onAppear(perform: startPermissionCheck)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Show DockAnchor") {
                    menuBarManager.showMainWindow()
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                
                Button(dockMonitor.isActive ? "Stop Protection" : "Start Protection") {
                    dockMonitor.toggleProtection()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
            }
        }
    }
    
    private func startPermissionCheck() {
        checkPermissions()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            withAnimation { self.hasPermissions = true }
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func setupMainApp() {
        appDelegate.setup(appSettings: appSettings, dockMonitor: dockMonitor, menuBarManager: menuBarManager)
        menuBarManager.setup(appSettings: appSettings, dockMonitor: dockMonitor)
        windowHiderDelegate.setup(appSettings: appSettings)
        
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.delegate = windowHiderDelegate
                window.center() // Center window on launch
                window.makeKeyAndOrderFront(nil)
            }
            // FORCE window to front because there is no Dock icon to click
            NSApp.activate(ignoringOtherApps: true)
        }
        
        DisplayManager.shared.refreshHardwareMap()
        dockMonitor.restoreSavedAnchor()
        
        if appSettings.runInBackground {
            dockMonitor.startMonitoring()
        }
    }
}

// MARK: - Application Delegate
class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var appSettings: AppSettings?
    private var dockMonitor: DockMonitor?
    private var menuBarManager: MenuBarManager?
    
    func setup(appSettings: AppSettings, dockMonitor: DockMonitor, menuBarManager: MenuBarManager) {
        self.appSettings = appSettings
        self.dockMonitor = dockMonitor
        self.menuBarManager = menuBarManager
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CHANGED: Respect the 'hideFromDock' setting on launch
        if let settings = appSettings {
            if settings.hideFromDock {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBarManager?.showMainWindow()
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        dockMonitor?.stopMonitoring()
    }
}

// MARK: - Menu Bar Manager
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var appSettings: AppSettings?
    private var dockMonitor: DockMonitor?
    private var cancellables = Set<AnyCancellable>()
    
    func setup(appSettings: AppSettings, dockMonitor: DockMonitor) {
        self.appSettings = appSettings
        self.dockMonitor = dockMonitor
        
        updateStatusBarVisibility(isVisible: appSettings.showStatusIcon)
        
        appSettings.$showStatusIcon
            .sink { [weak self] show in
                self?.updateStatusBarVisibility(isVisible: show)
            }
            .store(in: &cancellables)
        
        dockMonitor.$isActive
            .sink { [weak self] _ in self?.updateMenu() }
            .store(in: &cancellables)
            
        dockMonitor.$anchoredDisplayName
            .sink { [weak self] _ in self?.updateMenu() }
            .store(in: &cancellables)
    }
    
    private func updateStatusBarVisibility(isVisible: Bool) {
        if isVisible {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = statusItem?.button {
                    button.image = NSImage(systemSymbolName: "lock.laptopcomputer", accessibilityDescription: "DockAnchor")
                    button.action = #selector(menuBarClicked)
                    button.target = self
                }
                updateMenu()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    func updateMenu() {
        guard let dockMonitor = dockMonitor, let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        let statusTitle = dockMonitor.isActive ? "🟢 Protection Active" : "🔴 Protection Inactive"
        menu.addItem(NSMenuItem(title: statusTitle, action: nil, keyEquivalent: ""))
        
        let anchorTitle = "⚓️ \(dockMonitor.anchoredDisplayName)"
        menu.addItem(NSMenuItem(title: anchorTitle, action: nil, keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(
            title: dockMonitor.isActive ? "Stop Protection" : "Start Protection",
            action: #selector(toggleProtection),
            keyEquivalent: "p"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let setAnchorItem = NSMenuItem(title: "Set Anchor to Current Screen", action: #selector(setAnchorToCurrent), keyEquivalent: "s")
        setAnchorItem.target = self
        menu.addItem(setAnchorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let showItem = NSMenuItem(title: "Open Settings...", action: #selector(showMainWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func menuBarClicked() { }
    
    @objc func toggleProtection() { dockMonitor?.toggleProtection() }
    
    @objc func setAnchorToCurrent() { dockMonitor?.setAnchorToCurrentMouseDisplay() }
    
    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // If user wants to see the window, temporarily bring activation policy to regular
        // to ensure it behaves like a normal window, then switch back if needed.
        // Or just force front:
        for window in NSApp.windows {
            if window.contentViewController != nil {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
    
    @objc func quitApp() { NSApp.terminate(nil) }
}
