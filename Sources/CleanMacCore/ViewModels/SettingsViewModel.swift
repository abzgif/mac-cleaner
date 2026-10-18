import Foundation
import SwiftUI
import Combine
import ServiceManagement

/// ViewModel managing user preferences, excluded paths, and Smart Scan configurations.
@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var smartScanCategories: Set<ScanCategory> {
        didSet { saveCategories() }
    }
    
    @Published public var oldFilesAgeThresholdDays: Int {
        didSet { UserDefaults.standard.set(oldFilesAgeThresholdDays, forKey: "cleanmac_age_threshold") }
    }
    
    @Published public var autoEmptyTrash: Bool {
        didSet { UserDefaults.standard.set(autoEmptyTrash, forKey: "cleanmac_auto_empty_trash") }
    }
    
    @Published public var allowPermanentDeletion: Bool {
        didSet { UserDefaults.standard.set(allowPermanentDeletion, forKey: "cleanmac_allow_permanent_deletion") }
    }
    
    @Published public var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }
    
    @Published public var userExclusions: [String] {
        didSet { UserDefaults.standard.set(userExclusions, forKey: "cleanmac_user_exclusions") }
    }
    
    public init() {
        let defaults = UserDefaults.standard
        
        if let savedCats = defaults.stringArray(forKey: "cleanmac_smart_scan_categories") {
            self.smartScanCategories = Set(savedCats.compactMap { ScanCategory(rawValue: $0) })
        } else {
            self.smartScanCategories = Set(ScanCategory.allCases.filter { $0.isDefaultSmartScan })
        }
        
        let savedAge = defaults.integer(forKey: "cleanmac_age_threshold")
        self.oldFilesAgeThresholdDays = savedAge > 0 ? savedAge : 30
        
        self.autoEmptyTrash = defaults.bool(forKey: "cleanmac_auto_empty_trash")
        self.allowPermanentDeletion = defaults.bool(forKey: "cleanmac_allow_permanent_deletion")
        self.userExclusions = defaults.stringArray(forKey: "cleanmac_user_exclusions") ?? []
        
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            self.launchAtLogin = false
        }
    }
    
    public func addExclusion(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !userExclusions.contains(trimmed) else { return }
        userExclusions.append(trimmed)
    }
    
    public func removeExclusion(at index: Int) {
        guard index >= 0, index < userExclusions.count else { return }
        userExclusions.remove(at: index)
    }
    
    public func toggleCategory(_ category: ScanCategory) {
        if smartScanCategories.contains(category) {
            smartScanCategories.remove(category)
        } else {
            smartScanCategories.insert(category)
        }
    }
    
    private func saveCategories() {
        let rawValues = smartScanCategories.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: "cleanmac_smart_scan_categories")
    }
    
    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Silently handle in dev mode
            }
        }
    }
}
