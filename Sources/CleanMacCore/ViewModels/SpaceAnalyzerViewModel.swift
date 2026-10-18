import Foundation
import SwiftUI
import AppKit
import Combine

/// ViewModel managing the visual space lens drill-down navigation and actions.
@MainActor
public final class SpaceAnalyzerViewModel: ObservableObject {
    @Published public var currentDirectory: SpaceItem?
    @Published public var breadcrumbs: [SpaceItem] = []
    @Published public var isScanning: Bool = false
    @Published public var statusMessage: String?
    @Published public var itemPendingTrash: SpaceItem?
    @Published public var showTrashAlert: Bool = false
    
    private let service = SpaceAnalyzerService.shared
    private let safetyPolicy = SafetyPolicy.shared
    private let cleanupEngine = CleanupEngine.shared
    
    public init() {
        startScan(at: FileManager.default.homeDirectoryForCurrentUser)
    }
    
    public func startScan(at url: URL) {
        isScanning = true
        statusMessage = "Analyzing \(url.lastPathComponent)..."
        
        Task { [weak self] in
            guard let self = self else { return }
            let analyzed = await self.service.analyzeDirectory(at: url)
            self.currentDirectory = analyzed
            self.breadcrumbs = [analyzed]
            self.isScanning = false
            self.statusMessage = nil
        }
    }
    
    public func drillDown(into item: SpaceItem) {
        guard item.isDirectory else { return }
        isScanning = true
        
        Task { [weak self] in
            guard let self = self else { return }
            let analyzed = await self.service.analyzeDirectory(at: item.url)
            self.currentDirectory = analyzed
            self.breadcrumbs.append(analyzed)
            self.isScanning = false
        }
    }
    
    public func navigateTo(index: Int) {
        guard index >= 0 && index < breadcrumbs.count else { return }
        let target = breadcrumbs[index]
        breadcrumbs = Array(breadcrumbs.prefix(index + 1))
        
        if index == breadcrumbs.count - 1 && currentDirectory?.url == target.url {
            return
        }
        
        drillDown(into: target)
    }
    
    public func revealInFinder(item: SpaceItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
    
    public func confirmTrash(item: SpaceItem) {
        let check = safetyPolicy.validateDeletionSafety(for: item.url.path)
        switch check {
        case .failure(let violation):
            statusMessage = violation.localizedDescription
            return
        case .success:
            break
        }
        
        itemPendingTrash = item
        showTrashAlert = true
    }
    
    public func performTrash() {
        guard let item = itemPendingTrash else { return }
        showTrashAlert = false
        itemPendingTrash = nil
        
        do {
            try cleanupEngine.moveItemToTrash(at: item.url)
            statusMessage = "Moved '\(item.name)' to Trash."
            // Refresh current folder
            if let current = currentDirectory {
                startScan(at: current.url)
            }
        } catch {
            statusMessage = "Failed to move to Trash: \(error.localizedDescription)"
        }
    }
}
