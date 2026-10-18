import Foundation
import SwiftUI
import Combine

/// Selection mode strategy for duplicate clusters.
public enum DuplicateSelectionStrategy: String, CaseIterable, Identifiable, Sendable {
    case keepOldest = "Keep Oldest"
    case keepNewest = "Keep Newest"
    case unselectAll = "Unselect All"
    
    public var id: String { rawValue }
}

/// ViewModel for scanning, grouping, reviewing, and deleting duplicate files.
@MainActor
public final class DuplicateFinderViewModel: ObservableObject {
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var statusText: String = ""
    @Published public var showConfirmation: Bool = false
    @Published public var cleanupSummary: CleanupExecutionResult?
    
    private let cleanupEngine: CleanupEngine
    
    public init(cleanupEngine: CleanupEngine = .shared) {
        self.cleanupEngine = cleanupEngine
    }
    
    public var totalReclaimableBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.reclaimableSize }
    }
    
    public var selectedBytes: Int64 {
        duplicateGroups.flatMap { $0.files }
            .filter { $0.isSelected }
            .reduce(0) { $0 + $1.size }
    }
    
    public var selectedCount: Int {
        duplicateGroups.flatMap { $0.files }
            .filter { $0.isSelected }
            .count
    }
    
    public func scan(directories: [URL]? = nil) {
        guard !isScanning else { return }
        isScanning = true
        duplicateGroups = []
        statusText = "Scanning for identical files..."
        
        let scanner = DuplicateFinderScanner(directories: directories)
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let items = try await scanner.scan(onFoundItem: { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.statusText = "Comparing file hashes..."
                    }
                })
                
                var groups: [String: [ScannedItem]] = [:]
                for item in items {
                    if let hash = item.duplicateGroupId {
                        groups[hash, default: []].append(item)
                    }
                }
                
                self.duplicateGroups = groups.compactMap { (hash, files) in
                    guard let first = files.first else { return nil }
                    return DuplicateGroup(hash: hash, fileSize: first.size, files: files)
                }.sorted { $0.reclaimableSize > $1.reclaimableSize }
                
                self.statusText = "Found \(self.duplicateGroups.count) duplicate groups"
            } catch {
                self.statusText = "Scan failed: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }
    
    public func toggleItem(_ item: ScannedItem) {
        for groupIndex in duplicateGroups.indices {
            if let fileIndex = duplicateGroups[groupIndex].files.firstIndex(where: { $0.id == item.id }) {
                duplicateGroups[groupIndex].files[fileIndex].isSelected.toggle()
                break
            }
        }
    }
    
    public func applyStrategy(_ strategy: DuplicateSelectionStrategy) {
        for groupIndex in duplicateGroups.indices {
            var files = duplicateGroups[groupIndex].files
            let sorted = files.sorted { ($0.modificationDate ?? Date.distantPast) < ($1.modificationDate ?? Date.distantPast) }
            
            for (idx, sortedFile) in sorted.enumerated() {
                if let fileIdx = files.firstIndex(where: { $0.id == sortedFile.id }) {
                    switch strategy {
                    case .keepOldest:
                        files[fileIdx].isSelected = (idx != 0)
                    case .keepNewest:
                        files[fileIdx].isSelected = (idx != sorted.count - 1)
                    case .unselectAll:
                        files[fileIdx].isSelected = false
                    }
                }
            }
            duplicateGroups[groupIndex].files = files
        }
    }
    
    public func deleteSelected(userExclusions: Set<String> = [], autoEmptyTrash: Bool = false) {
        let toDelete = duplicateGroups.flatMap { $0.files }.filter { $0.isSelected }
        guard !toDelete.isEmpty else { return }
        
        isCleaning = true
        showConfirmation = false
        
        let engine = cleanupEngine
        
        Task { [weak self] in
            guard let self = self else { return }
            let result = try? await engine.clean(
                items: toDelete,
                userExclusions: userExclusions,
                autoEmptyTrash: autoEmptyTrash
            )
            self.cleanupSummary = result
            
            let deletedIDs = Set(toDelete.map { $0.id })
            for groupIndex in self.duplicateGroups.indices {
                self.duplicateGroups[groupIndex].files.removeAll { deletedIDs.contains($0.id) }
            }
            self.duplicateGroups.removeAll { $0.files.count <= 1 }
            self.isCleaning = false
        }
    }
}
