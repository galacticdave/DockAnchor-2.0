//
//  DisplayManager.swift
//  DockAnchor
//
//  Created for DockAnchor v2.0
//

import Foundation
import CoreGraphics
import Cocoa

struct HardwareDisplay: Identifiable, Equatable, Hashable {
    let id: String // Persistent UUID/Serial
    let directDisplayID: CGDirectDisplayID // Volatile ID (for current session)
    let name: String
    let isBuiltIn: Bool
}

class DisplayManager {
    static let shared = DisplayManager()
    
    private let kCollectionsKey = "DockAnchor_Collections"
    
    // Mapping of Volatile ID -> Persistent Info
    var currentDisplays: [HardwareDisplay] = []
    
    // MARK: - Hardware Identification
    
    func refreshHardwareMap() {
        var newMap: [HardwareDisplay] = []
        
        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { continue }
            
            // Generate Persistent Fingerprint
            var persistentID = "Unknown"
            
            // FIX: Explicitly unwrap the Unmanaged<CFUUID>
            // We use takeRetainedValue() to transfer ownership to Swift memory management
            if let uuidUnmanaged = CGDisplayCreateUUIDFromDisplayID(displayID) {
                let uuid = uuidUnmanaged.takeRetainedValue()
                if let uuidString = CFUUIDCreateString(nil, uuid) as String? {
                    persistentID = uuidString
                }
            }
            
            // Determine if built-in
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
    
    /// Generates a signature for the current set of connected monitors
    private func currentEnvironmentSignature() -> String {
        // Sort IDs to ensure order doesn't matter (e.g., plugging left vs right first)
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
        
        // Find the monitor that matches the saved ID
        return currentDisplays.first(where: { $0.id == savedAnchorID })
    }
    
    func getDisplayByPersistentID(_ id: String) -> HardwareDisplay? {
        return currentDisplays.first(where: { $0.id == id })
    }
    
    func getDisplayByDirectID(_ id: CGDirectDisplayID) -> HardwareDisplay? {
        return currentDisplays.first(where: { $0.directDisplayID == id })
    }
}
