//
//  ContentView.swift
//  DockAnchor
//
//  Created by Bradley Wyatt on 7/2/25.
//  Copyright © 2025 Bradley Wyatt.
//  Modified by Dave J. on 1/13/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasPermissions: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Permissions Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("DockAnchor needs Accessibility access to:\n1. Detect mouse position\n2. Block Dock movement\n3. Detect the 'Option' key for unlocking")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Open System Settings") {
                openSecurityPane()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("Waiting for permission...")
                .font(.caption)
                .italic()
                .opacity(0.6)
        }
        .padding(40)
        .frame(width: 450, height: 400)
    }
    
    func openSecurityPane() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Main Interface
struct ContentView: View {
    @EnvironmentObject var dockMonitor: DockMonitor
    @EnvironmentObject var appSettings: AppSettings
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: dockMonitor.isActive ? "lock.laptopcomputer" : "lock.open.laptopcomputer")
                    .font(.system(size: 42))
                    .foregroundColor(dockMonitor.isActive ? .green : .orange)
                    .padding(.top, 20)
                
                Text("DockAnchor")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(dockMonitor.isActive ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(dockMonitor.statusMessage)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(.bottom, 20)
            
            Divider()
            
            // Main Controls
            VStack(spacing: 20) {
                
                // Current Anchor Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT ANCHOR")
                        .font(.xs)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "display")
                        Text(dockMonitor.anchoredDisplayName)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    Text("This anchor is saved for your current monitor setup.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        dockMonitor.toggleProtection()
                    }) {
                        HStack {
                            Image(systemName: dockMonitor.isActive ? "pause.circle.fill" : "play.circle.fill")
                            Text(dockMonitor.isActive ? "Stop" : "Start")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(dockMonitor.isActive ? .orange : .green)
                    
                    Button(action: {
                        dockMonitor.setAnchorToCurrentMouseDisplay()
                    }) {
                        Text("Set Anchor Here")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            
            Spacer()
            
            // Footer / Settings
            HStack {
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSettings) {
                    SettingsView()
                        .frame(width: 300, height: 350)
                }
                
                Spacer()
                Text("Hold 'Option' to temporarily unlock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 350, height: 450)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Startup")) {
                Toggle("Launch at Login", isOn: $appSettings.startAtLogin)
                Toggle("Run in Background", isOn: $appSettings.runInBackground)
            }
            
            Section(header: Text("Appearance")) {
                Toggle("Show Menu Bar Icon", isOn: $appSettings.showStatusIcon)
                Toggle("Hide from Dock", isOn: $appSettings.hideFromDock)
            }
            
            Section(footer: Text("If you hide the icon, relaunch the app to restore settings.")) {
                Button("Quit DockAnchor") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding()
    }
}

extension Font {
    static let xs = Font.system(size: 10)
}
