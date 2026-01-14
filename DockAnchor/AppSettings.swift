//
//  AppSettings.swift
//  DockAnchor
//
//  Created for DockAnchor v2.0
//

import Foundation
import SwiftUI
import ServiceManagement

class AppSettings: ObservableObject {
    @Published var startAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(startAtLogin, forKey: "startAtLogin")
            updateLoginItem()
        }
    }
    
    @Published var runInBackground: Bool {
        didSet {
            UserDefaults.standard.set(runInBackground, forKey: "runInBackground")
        }
    }
    
    @Published var showStatusIcon: Bool {
        didSet {
            UserDefaults.standard.set(showStatusIcon, forKey: "showStatusIcon")
        }
    }
    
    @Published var hideFromDock: Bool {
        didSet {
            UserDefaults.standard.set(hideFromDock, forKey: "hideFromDock")
            // Apply change immediately
            if hideFromDock {
                NSApp.setActivationPolicy(.accessory)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
    
    init() {
        self.runInBackground = UserDefaults.standard.object(forKey: "runInBackground") as? Bool ?? true
        self.showStatusIcon = UserDefaults.standard.object(forKey: "showStatusIcon") as? Bool ?? true
        
        // CHANGED: Default is now TRUE (Hide from Dock)
        self.hideFromDock = UserDefaults.standard.object(forKey: "hideFromDock") as? Bool ?? true
        
        // Sync login state with system
        let currentStatus = SMAppService.mainApp.status == .enabled
        self.startAtLogin = currentStatus
    }
    
    private func updateLoginItem() {
        do {
            if startAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}
