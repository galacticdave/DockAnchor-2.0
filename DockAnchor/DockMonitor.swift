//
//  DockMonitor.swift
//  DockAnchor
//
//  Created by Bradley Wyatt on 7/2/25.
//  Copyright © 2025 Bradley Wyatt.
//  Modified by Dave J. on 1/13/26.
//

import Foundation
import Cocoa
import CoreGraphics
import Combine

class DockMonitor: ObservableObject {
    static let shared = DockMonitor()
    
    @Published var isActive = false
    @Published var anchoredDisplayName: String = "None"
    @Published var statusMessage = "Ready"
    @Published var isUnlockedTemporarily = false
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var anchorDisplay: HardwareDisplay?
    private var globalMonitor: Any?
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    // MARK: - Anchor Logic
    
    @objc private func handleScreenChange() {
        print("📺 Screen parameters changed. Re-evaluating environment...")
        DisplayManager.shared.refreshHardwareMap()
        restoreSavedAnchor()
    }
    
    func setAnchorToCurrentMouseDisplay() {
        let mouseLoc = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }),
           let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            
            if let hwDisplay = DisplayManager.shared.getDisplayByDirectID(displayID) {
                self.anchorDisplay = hwDisplay
                self.anchoredDisplayName = hwDisplay.name
                DisplayManager.shared.saveAnchorForCurrentEnvironment(anchorPersistentID: hwDisplay.id)
                updateStatus("Anchored to: \(hwDisplay.name)")
            }
        }
    }
    
    func restoreSavedAnchor() {
        if let savedDisplay = DisplayManager.shared.getSavedAnchorForCurrentEnvironment() {
            self.anchorDisplay = savedDisplay
            self.anchoredDisplayName = savedDisplay.name
            updateStatus("Restored Anchor: \(savedDisplay.name)")
        } else {
            if let mainScreen = DisplayManager.shared.currentDisplays.first(where: { $0.isBuiltIn }) ?? DisplayManager.shared.currentDisplays.first {
                self.anchorDisplay = mainScreen
                self.anchoredDisplayName = mainScreen.name + " (Default)"
                updateStatus("Defaulted to: \(mainScreen.name)")
            }
        }
    }
    
    // MARK: - Protection Logic
    
    func toggleProtection() {
        if isActive {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        guard !isActive else { return }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<DockMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleMouseEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            updateStatus("Failed to create Event Tap. Check Permissions.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        isActive = true
        updateStatus("Protection Active")
    }
    
    func stopMonitoring() {
        guard isActive else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
            runLoopSource = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        isActive = false
        updateStatus("Protection Stopped")
    }
    
    // MARK: - Event Handling
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let isOptionHeld = event.modifierFlags.contains(.option)
        DispatchQueue.main.async {
            if isOptionHeld != self.isUnlockedTemporarily {
                self.isUnlockedTemporarily = isOptionHeld
                self.updateStatus(isOptionHeld ? "UNLOCKED (Option Held)" : "Protection Active")
            }
        }
    }
    
    private func handleMouseEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if isUnlockedTemporarily { return Unmanaged.passUnretained(event) }
        guard let anchorID = anchorDisplay?.directDisplayID else { return Unmanaged.passUnretained(event) }
        
        let location = event.location
        
        for screen in NSScreen.screens {
            guard let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            
            if screenID == anchorID { continue }
            
            let bounds = CGDisplayBounds(screenID)
            
            if location.x >= bounds.minX && location.x <= bounds.maxX {
                if location.y >= bounds.minY && location.y <= bounds.maxY {
                    let bottomThreshold = bounds.maxY - 15
                    if location.y >= bottomThreshold {
                        return nil
                    }
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func updateStatus(_ msg: String) {
        DispatchQueue.main.async {
            self.statusMessage = msg
        }
    }
}
