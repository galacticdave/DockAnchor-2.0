//
//  DockAnchorApp.swift
//  DockAnchor
//
//  Created by Bradley Wyatt on 7/2/25.
//  Copyright © 2025 Bradley Wyatt.
//  Modified by Dave J. on 1/13/26.
//

import SwiftUI
import ServiceManagement
import Combine

class WindowHiderDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        if AppSettings.shared.hideFromDock {
            NSApp.setActivationPolicy(.accessory)
        }
        return false
    }
}

@main
struct DockAnchorApp: App {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var dockMonitor = DockMonitor.shared
    
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
                    .onAppear {
                        bindWindowDelegate()
                    }
                    .onOpenURL { url in
                        NSApp.activate(ignoringOtherApps: true)
                    }
            } else {
                OnboardingView(hasPermissions: $hasPermissions)
                    .onAppear(perform: startPermissionCheck)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "main"))
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Show DockAnchor") {
                    MenuBarManager.shared.showMainWindow()
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                
                Button(dockMonitor.isActive ? "Stop Protection" : "Start Protection") {
                    dockMonitor.toggleProtection()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
            }
        }
    }
    
    private func bindWindowDelegate() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.delegate = windowHiderDelegate
                window.center()
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
            appDelegate.startServices()
        }
    }
}

// MARK: - Application Delegate
class ApplicationDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppSettings.shared.hideFromDock {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
        
        if AXIsProcessTrusted() {
            startServices()
        }
    }
    
    func startServices() {
        print("🚀 Starting DockAnchor Services...")
        MenuBarManager.shared.start()
        DisplayManager.shared.refreshHardwareMap()
        DockMonitor.shared.restoreSavedAnchor()
        
        if AppSettings.shared.runInBackground {
            DockMonitor.shared.startMonitoring()
        }
    }
    
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MenuBarManager.shared.showMainWindow()
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        DockMonitor.shared.stopMonitoring()
    }
}

// MARK: - Menu Bar Manager
class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    func start() {
        let settings = AppSettings.shared
        let monitor = DockMonitor.shared
        
        updateStatusBarVisibility(isVisible: settings.showStatusIcon)
        
        settings.$showStatusIcon
            .sink { [weak self] show in self?.updateStatusBarVisibility(isVisible: show) }
            .store(in: &cancellables)
        
        monitor.$isActive
            .sink { [weak self] _ in self?.updateMenu() }
            .store(in: &cancellables)
            
        monitor.$anchoredDisplayName
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
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        let monitor = DockMonitor.shared
        
        let statusTitle = monitor.isActive ? "🟢 Protection Active" : "🔴 Protection Inactive"
        menu.addItem(NSMenuItem(title: statusTitle, action: nil, keyEquivalent: ""))
        
        let anchorTitle = "⚓️ \(monitor.anchoredDisplayName)"
        menu.addItem(NSMenuItem(title: anchorTitle, action: nil, keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(
            title: monitor.isActive ? "Stop Protection" : "Start Protection",
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
    
    @objc func toggleProtection() { DockMonitor.shared.toggleProtection() }
    
    @objc func setAnchorToCurrent() { DockMonitor.shared.setAnchorToCurrentMouseDisplay() }
    
    @objc func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        var foundWindow = false
        for window in NSApp.windows {
            if window.contentViewController != nil {
                window.makeKeyAndOrderFront(nil)
                foundWindow = true
                return
            }
        }
        
        if !foundWindow {
            if let url = URL(string: "dockanchor://main") {
                NSWorkspace.shared.open(url)
            }
        }
        
        if AppSettings.shared.hideFromDock {
             NSApp.setActivationPolicy(.regular)
             NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func quitApp() { NSApp.terminate(nil) }
}
