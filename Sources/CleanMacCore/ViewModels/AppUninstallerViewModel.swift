import Foundation
import SwiftUI
import Combine

/// ViewModel managing installed applications inspection, multi-app selection, and complete uninstallation.
@MainActor
public final class AppUninstallerViewModel: ObservableObject {
    @Published public var apps: [AppItem] = []
    @Published public var searchText: String = ""
    @Published public var isScanning: Bool = false
    @Published public var isUninstalling: Bool = false
    @Published public var selectedAppId: String?
    @Published public var showConfirmation: Bool = false
    @Published public var uninstallSummary: CleanupExecutionResult?
    @Published public var statusMessage: String?
    
    private let appScanner = AppUninstallerScanner()
    private let cleanupEngine: CleanupEngine
    
    public init(cleanupEngine: CleanupEngine = .shared) {
        self.cleanupEngine = cleanupEngine
    }
    
    // MARK: - Computed Properties
    
    public var userApps: [AppItem] {
        apps.filter { !$0.isSystemApp }
    }
    
    public var filteredApps: [AppItem] {
        let term = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if term.isEmpty {
            return userApps
        } else {
            return userApps.filter {
                $0.name.lowercased().contains(term) ||
                ($0.bundleIdentifier?.lowercased().contains(term) == true)
            }
        }
    }
    
    /// Currently focused app in the detail inspector.
    public var selectedApp: AppItem? {
        userApps.first(where: { $0.id == selectedAppId }) ?? checkedApps.first
    }
    
    /// All applications checked by the user for batch uninstallation.
    public var checkedApps: [AppItem] {
        userApps.filter { $0.isSelected }
    }
    
    /// Target applications that will be uninstalled when the user clicks Uninstall.
    /// If one or more checkboxes are ticked, uninstalls all checked apps; otherwise uninstalls the currently focused app.
    public var appsToUninstall: [AppItem] {
        if !checkedApps.isEmpty {
            return checkedApps
        }
        if let focused = selectedApp {
            return [focused]
        }
        return []
    }
    
    /// Total bytes across all apps queued for uninstallation (app bundles + checked related files).
    public var totalUninstallSize: Int64 {
        appsToUninstall.reduce(0) { sum, app in
            let relatedBytes = app.relatedItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
            return sum + app.appSize + relatedBytes
        }
    }
    
    /// Total file/folder count across all apps queued for uninstallation.
    public var totalUninstallItemCount: Int {
        appsToUninstall.reduce(0) { count, app in
            count + 1 + app.relatedItems.filter { $0.isSelected }.count
        }
    }
    
    // MARK: - Scanning
    
    public func scan() {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        
        Task { [weak self] in
            guard let self = self else { return }
            let scannedApps = await self.appScanner.scanInstalledApps()
            self.apps = scannedApps
            
            if self.selectedAppId == nil || !self.filteredApps.contains(where: { $0.id == self.selectedAppId }) {
                self.selectedAppId = self.filteredApps.first?.id
            }
            self.isScanning = false
        }
    }
    
    // MARK: - Multi-App Selection & File Toggle Actions
    
    public func toggleAppSelection(_ app: AppItem) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].isSelected.toggle()
        if apps[index].isSelected {
            selectedAppId = app.id
        }
    }
    
    public func selectAllFiltered(_ select: Bool) {
        let visibleIDs = Set(filteredApps.map { $0.id })
        for index in apps.indices where visibleIDs.contains(apps[index].id) && !apps[index].isSystemApp {
            apps[index].isSelected = select
        }
    }
    
    public func toggleRelatedFile(in app: AppItem, itemId: UUID) {
        guard let appIndex = apps.firstIndex(where: { $0.id == app.id }),
              let itemIndex = apps[appIndex].relatedItems.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        apps[appIndex].relatedItems[itemIndex].isSelected.toggle()
    }
    
    public func promptUninstall() {
        guard !appsToUninstall.isEmpty else { return }
        showConfirmation = true
    }
    
    /// Uninstalls one or multiple selected applications and cleans all their checked support, cache, and preference files.
    public func executeUninstall(userExclusions: Set<String> = [], autoEmptyTrash: Bool = false) {
        let targets = appsToUninstall.filter { !$0.isSystemApp }
        guard !targets.isEmpty else { return }
        
        isUninstalling = true
        showConfirmation = false
        
        // 1. Terminate running processes for all target applications
        for app in targets {
            for runningApp in NSWorkspace.shared.runningApplications {
                if runningApp.bundleIdentifier == app.bundleIdentifier ||
                   runningApp.bundleURL == app.bundleURL ||
                   runningApp.localizedName == app.name {
                    runningApp.terminate()
                }
            }
        }
        
        // 2. Collect all app bundles and their checked related files
        var itemsToDelete: [ScannedItem] = []
        for app in targets {
            let appBundleItem = ScannedItem(
                url: app.bundleURL,
                displayName: "\(app.name).app",
                size: app.appSize,
                category: .appLeftovers,
                isSelected: true
            )
            itemsToDelete.append(appBundleItem)
            itemsToDelete.append(contentsOf: app.relatedItems.filter { $0.isSelected })
        }
        
        let engine = cleanupEngine
        Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            
            let result = try? await engine.clean(
                items: itemsToDelete,
                userExclusions: userExclusions,
                autoEmptyTrash: autoEmptyTrash,
                permanentDelete: false,
                isAppUninstall: true
            )
            self.uninstallSummary = result
            
            // Remove successfully uninstalled apps from list
            var removedCount = 0
            for app in targets {
                if !FileManager.default.fileExists(atPath: app.bundleURL.path) {
                    self.apps.removeAll { $0.id == app.id }
                    removedCount += 1
                }
            }
            
            self.selectedAppId = self.filteredApps.first?.id
            let freedBytes = result?.report.bytesFreed ?? 0
            
            if removedCount > 0 {
                if removedCount == 1, let first = targets.first {
                    self.statusMessage = "Uninstalled \(first.name) and cleaned its residual files (\(ByteFormatter.format(freedBytes)) freed)."
                } else {
                    self.statusMessage = "Uninstalled \(removedCount) applications and cleaned their residual files (\(ByteFormatter.format(freedBytes)) freed)."
                }
            } else {
                let failReason = result?.permissionFailures.first ?? "Permission denied to remove application bundle."
                self.statusMessage = "Could not complete uninstall: \(failReason)"
            }
            self.isUninstalling = false
        }
    }
}
