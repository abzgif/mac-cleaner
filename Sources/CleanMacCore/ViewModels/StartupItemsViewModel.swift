import Foundation
import SwiftUI
import Combine

/// ViewModel managing startup items, background helpers, and orphaned daemons.
@MainActor
public final class StartupItemsViewModel: ObservableObject {
    @Published public var items: [StartupItem] = []
    @Published public var isScanning: Bool = false
    @Published public var isRemoving: Bool = false
    @Published public var showConfirmation: Bool = false
    @Published public var filterType: StartupItemType? = nil
    @Published public var statusMessage: String?
    
    private let service = StartupItemsService.shared
    
    public init() {
        refresh()
    }
    
    public var filteredItems: [StartupItem] {
        if let filter = filterType {
            return items.filter { $0.itemType == filter }
        }
        return items
    }
    
    public var selectedItems: [StartupItem] {
        items.filter { $0.isSelected }
    }
    
    public var orphanedCount: Int {
        items.filter { $0.isOrphaned }.count
    }
    
    public func refresh() {
        isScanning = true
        Task { [weak self] in
            guard let self = self else { return }
            let loaded = self.service.scanStartupItems()
            self.items = loaded
            self.isScanning = false
        }
    }
    
    public func toggleItem(_ item: StartupItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isSelected.toggle()
        }
    }
    
    public func selectAllOrphaned() {
        for index in items.indices {
            items[index].isSelected = items[index].isOrphaned
        }
    }
    
    public func removeSelected() {
        let toRemove = selectedItems
        guard !toRemove.isEmpty else { return }
        
        isRemoving = true
        showConfirmation = false
        
        Task { [weak self] in
            guard let self = self else { return }
            let errors = self.service.removeItems(toRemove)
            if errors.isEmpty {
                self.statusMessage = "Successfully removed \(toRemove.count) startup items to Trash."
            } else {
                self.statusMessage = "Removed \(toRemove.count - errors.count) items with \(errors.count) permission errors."
            }
            self.refresh()
            self.isRemoving = false
        }
    }
}
