import Foundation
import SwiftUI
import Combine

/// Categories for filtering installed applications and leftovers.
public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case all = "All Applications"
    case user = "Third-Party Apps"
    case leftovers = "Leftovers & Orphans"
    case unused = "Unused Apps"
    case large = "Large Apps (>500MB)"
    case system = "System Apps"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .user: return "person.crop.circle.fill"
        case .leftovers: return "puzzlepiece.extension.fill"
        case .unused: return "clock.badge.questionmark.fill"
        case .large: return "externaldrive.fill"
        case .system: return "apple.logo"
        }
    }
}

/// ViewModel managing installed applications inspection, leftover detection, and complete uninstallation.
@MainActor
public final class AppUninstallerViewModel: ObservableObject {
    @Published public var apps: [AppItem] = []
    @Published public var orphanedLeftovers: [ScannedItem] = []
    @Published public var selectedSection: AppSection = .all
    @Published public var searchText: String = ""
    @Published public var isScanning: Bool = false
    @Published public var isUninstalling: Bool = false
    @Published public var selectedAppId: String?
    @Published public var showConfirmation: Bool = false
    @Published public var uninstallSummary: CleanupExecutionResult?
    @Published public var statusMessage: String?
    
    private let appScanner = AppUninstallerScanner()
    private let leftoversScanner = AppLeftoversScanner()
    private let cleanupEngine: CleanupEngine
    
    public init(cleanupEngine: CleanupEngine = .shared) {
        self.cleanupEngine = cleanupEngine
    }
    
    // MARK: - Section Counts
    
    public var allCount: Int { apps.count }
    public var userCount: Int { apps.filter { !$0.isSystemApp }.count }
    public var leftoversCount: Int { orphanedLeftovers.count }
    public var unusedCount: Int { apps.filter { $0.isUnused && !$0.isSystemApp }.count }
    public var largeCount: Int { apps.filter { $0.isLarge }.count }
    public var systemCount: Int { apps.filter { $0.isSystemApp }.count }
    
    public func count(for section: AppSection) -> Int {
        switch section {
        case .all: return allCount
        case .user: return userCount
        case .leftovers: return leftoversCount
        case .unused: return unusedCount
        case .large: return largeCount
        case .system: return systemCount
        }
    }
    
    // MARK: - Filtered Apps
    
    public var filteredApps: [AppItem] {
        let baseList: [AppItem]
        switch selectedSection {
        case .all:
            baseList = apps
        case .user:
            baseList = apps.filter { !$0.isSystemApp }
        case .unused:
            baseList = apps.filter { $0.isUnused && !$0.isSystemApp }
        case .large:
            baseList = apps.filter { $0.isLarge }
        case .system:
            baseList = apps.filter { $0.isSystemApp }
        case .leftovers:
            baseList = []
        }
        
        let term = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if term.isEmpty {
            return baseList
        } else {
            return baseList.filter {
                $0.name.lowercased().contains(term) ||
                ($0.bundleIdentifier?.lowercased().contains(term) == true)
            }
        }
    }
    
    public var filteredLeftovers: [ScannedItem] {
        let term = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if term.isEmpty {
            return orphanedLeftovers
        } else {
            return orphanedLeftovers.filter {
                $0.displayName.lowercased().contains(term) ||
                $0.path.lowercased().contains(term)
            }
        }
    }
    
    public var selectedApp: AppItem? {
        apps.first(where: { $0.id == selectedAppId })
    }
    
    // MARK: - Scanning
    
    public func scan() {
        guard !isScanning else { return }
        isScanning = true
        apps = []
        orphanedLeftovers = []
        
        Task { [weak self] in
            guard let self = self else { return }
            async let appsTask = self.appScanner.scanInstalledApps()
            async let leftoversTask = (try? self.leftoversScanner.scan(onFoundItem: nil)) ?? []
            
            let (scannedApps, scannedLeftovers) = await (appsTask, leftoversTask)
            
            self.apps = scannedApps
            self.orphanedLeftovers = scannedLeftovers
            
            if self.selectedAppId == nil, let first = self.filteredApps.first {
                self.selectedAppId = first.id
            }
            self.isScanning = false
        }
    }
    
    // MARK: - App Item Actions
    
    public func toggleRelatedFile(in app: AppItem, itemId: UUID) {
        guard let appIndex = apps.firstIndex(where: { $0.id == app.id }),
              let itemIndex = apps[appIndex].relatedItems.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        apps[appIndex].relatedItems[itemIndex].isSelected.toggle()
    }
    
    public func promptUninstall() {
        guard selectedApp != nil else { return }
        showConfirmation = true
    }
    
    public func executeUninstall(userExclusions: Set<String> = [], autoEmptyTrash: Bool = false) {
        guard let app = selectedApp else { return }
        guard !app.isSystemApp else { return }
        
        isUninstalling = true
        showConfirmation = false
        
        // 1. Terminate running process if the application is active
        for runningApp in NSWorkspace.shared.runningApplications {
            if runningApp.bundleIdentifier == app.bundleIdentifier ||
               runningApp.bundleURL == app.bundleURL ||
               runningApp.localizedName == app.name {
                runningApp.terminate()
            }
        }
        
        var itemsToDelete: [ScannedItem] = []
        let appBundleItem = ScannedItem(
            url: app.bundleURL,
            displayName: "\(app.name).app",
            size: app.appSize,
            category: .appLeftovers,
            isSelected: true
        )
        itemsToDelete.append(appBundleItem)
        itemsToDelete.append(contentsOf: app.relatedItems.filter { $0.isSelected })
        
        let engine = cleanupEngine
        Task { [weak self] in
            guard let self = self else { return }
            // Brief wait to allow process termination
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let result = try? await engine.clean(
                items: itemsToDelete,
                userExclusions: userExclusions,
                autoEmptyTrash: autoEmptyTrash
            )
            self.uninstallSummary = result
            
            // Check if application bundle was actually removed from disk
            let appStillOnDisk = FileManager.default.fileExists(atPath: app.bundleURL.path)
            if !appStillOnDisk {
                self.apps.removeAll { $0.id == app.id }
                self.selectedAppId = self.filteredApps.first?.id
                self.statusMessage = "Successfully uninstalled \(app.name)."
            } else {
                let failReason = result?.permissionFailures.first ?? "Permission denied to remove /Applications bundle."
                self.statusMessage = "Could not uninstall \(app.name): \(failReason)"
            }
            self.isUninstalling = false
        }
    }
    
    // MARK: - Orphaned Leftovers Actions
    
    public func toggleLeftover(_ item: ScannedItem) {
        if let idx = orphanedLeftovers.firstIndex(where: { $0.id == item.id }) {
            orphanedLeftovers[idx].isSelected.toggle()
        }
    }
    
    public func selectAllLeftovers(_ select: Bool = true) {
        for idx in orphanedLeftovers.indices {
            orphanedLeftovers[idx].isSelected = select
        }
    }
    
    public func cleanSelectedLeftovers(userExclusions: Set<String> = [], autoEmptyTrash: Bool = false) {
        let toClean = orphanedLeftovers.filter { $0.isSelected }
        guard !toClean.isEmpty else { return }
        
        isUninstalling = true
        let engine = cleanupEngine
        
        Task { [weak self] in
            guard let self = self else { return }
            let result = try? await engine.clean(
                items: toClean,
                userExclusions: userExclusions,
                autoEmptyTrash: autoEmptyTrash
            )
            self.uninstallSummary = result
            let removedIDs = Set(toClean.map { $0.id })
            self.orphanedLeftovers.removeAll { removedIDs.contains($0.id) }
            self.statusMessage = "Removed \(toClean.count) orphaned residual items to Trash."
            self.isUninstalling = false
        }
    }
}
