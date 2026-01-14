//
//  AppSettings.swift
//  DockAnchor
//
//  Created by Bradley Wyatt on 7/2/25.
//  Copyright © 2025 Bradley Wyatt.
//  Modified by Dave J. on 1/13/26.
//

import Foundation
import SwiftUI
import ServiceManagement

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
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
        self.hideFromDock = UserDefaults.standard.object(forKey: "hideFromDock") as? Bool ?? false
        
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
