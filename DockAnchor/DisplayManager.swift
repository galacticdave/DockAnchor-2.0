//
//  DisplayManager.swift
//  DockAnchor
//
//  Created by Bradley Wyatt on 7/2/25.
//  Copyright © 2025 Bradley Wyatt.
//  Modified by Dave J. on 1/13/26.
//

import Foundation
import CoreGraphics
import Cocoa

struct HardwareDisplay: Identifiable, Equatable, Hashable {
    let id: String
    let directDisplayID: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
}

class DisplayManager {
    static let shared = DisplayManager()
    
    private let kCollectionsKey = "DockAnchor_Collections"
    
    var currentDisplays: [HardwareDisplay] = []
    
    // MARK: - Hardware Identification
    
    func refreshHardwareMap() {
        var newMap: [HardwareDisplay] = []
        
        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            
            var persistentID = "Unknown"
            
            if let uuidUnmanaged = CGDisplayCreateUUIDFromDisplayID(displayID) {
                let uuid = uuidUnmanaged.takeRetainedValue()
                if let uuidString = CFUUIDCreateString(nil, uuid) as String? {
                    persistentID = uuidString
                }
            }
            
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            
            let display = HardwareDisplay(
                id: persistentID,
                directDisplayID: displayID,
                name: screen.localizedName,
                isBuiltIn: isBuiltIn
            )
            
            newMap.append(display)
        }
        
        self.currentDisplays = newMap
        print("🖥️ Display Map Refreshed: \(currentDisplays.map { $0.name })")
    }
    
    // MARK: - Environment Collections logic
    
    private func currentEnvironmentSignature() -> String {
        let ids = currentDisplays.map { $0.id }.sorted()
        return ids.joined(separator: "|")
    }
    
    func saveAnchorForCurrentEnvironment(anchorPersistentID: String) {
        let signature = currentEnvironmentSignature()
        var collections = UserDefaults.standard.dictionary(forKey: kCollectionsKey) as? [String: String] ?? [:]
        
        collections[signature] = anchorPersistentID
        UserDefaults.standard.set(collections, forKey: kCollectionsKey)
        
        print("✅ Saved Collection: Environment [\(signature)] -> Anchor [\(anchorPersistentID)]")
    }
    
    func getSavedAnchorForCurrentEnvironment() -> HardwareDisplay? {
        let signature = currentEnvironmentSignature()
        let collections = UserDefaults.standard.dictionary(forKey: kCollectionsKey) as? [String: String] ?? [:]
        
        guard let savedAnchorID = collections[signature] else {
            print("⚠️ No saved anchor for this environment.")
            return nil
        }
        
        return currentDisplays.first(where: { $0.id == savedAnchorID })
    }
    
    func getDisplayByPersistentID(_ id: String) -> HardwareDisplay? {
        return currentDisplays.first(where: { $0.id == id })
    }
    
    func getDisplayByDirectID(_ id: CGDirectDisplayID) -> HardwareDisplay? {
        return currentDisplays.first(where: { $0.directDisplayID == id })
    }
}
