import Foundation
import SwiftUI
import Combine

public enum LargeFileSortOption: String, CaseIterable, Identifiable, Sendable {
    case sizeDescending = "Largest First"
    case dateOldest = "Oldest First"
    case name = "File Name"
    
    public var id: String { rawValue }
}

/// ViewModel for managing, filtering, and cleaning large & old files.
@MainActor
public final class LargeOldFilesViewModel: ObservableObject {
    @Published public var items: [ScannedItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var minSizeMB: Int = 50
    @Published public var minAgeDays: Int = 90
    @Published public var sortOption: LargeFileSortOption = .sizeDescending
    @Published public var showConfirmation: Bool = false
    @Published public var cleanupSummary: CleanupExecutionResult?
    
    private let cleanupEngine: CleanupEngine
    
    public init(cleanupEngine: CleanupEngine = .shared) {
        self.cleanupEngine = cleanupEngine
    }
    
    public var sortedItems: [ScannedItem] {
        switch sortOption {
        case .sizeDescending:
            return items.sorted { $0.size > $1.size }
        case .dateOldest:
            return items.sorted { ($0.modificationDate ?? Date.distantPast) < ($1.modificationDate ?? Date.distantPast) }
        case .name:
            return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }
    
    public var selectedItems: [ScannedItem] {
        items.filter { $0.isSelected }
    }
    
    public var selectedTotalSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }
    
    public func scan() {
        guard !isScanning else { return }
        isScanning = true
        items = []
        
        let scanner = LargeOldFilesScanner(minSizeMB: minSizeMB, minAgeDays: minAgeDays)
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let found = try await scanner.scan(onFoundItem: { [weak self] item in
                    Task { @MainActor [weak self] in
                        self?.items.append(item)
                    }
                })
                self.items = found
            } catch {
                // Ignore error
            }
            self.isScanning = false
        }
    }
    
    public func toggleItem(_ item: ScannedItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isSelected.toggle()
        }
    }
    
    public func selectAll(_ select: Bool) {
        for index in items.indices {
            items[index].isSelected = select
        }
    }
    
    public func deleteSelected(userExclusions: Set<String> = [], autoEmptyTrash: Bool = false) {
        let toDelete = selectedItems
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
            self.items.removeAll { deletedIDs.contains($0.id) }
            self.isCleaning = false
        }
    }
}
