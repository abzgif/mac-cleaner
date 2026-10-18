import Foundation
import SwiftUI
import Combine

/// Manages the state, live progress, category breakdowns, and cleanup workflow for Smart Scan.
@MainActor
public final class SmartScanViewModel: ObservableObject {
    @Published public var isScanning: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var hasCompletedScan: Bool = false
    @Published public var progress: ScanProgress?
    @Published public var scanResult: ScanResult = ScanResult()
    
    @Published public var selectedCategories: Set<ScanCategory>
    @Published public var expandedCategories: Set<ScanCategory> = []
    
    @Published public var showConfirmationSheet: Bool = false
    @Published public var showResultSheet: Bool = false
    @Published public var lastCleanupResult: CleanupExecutionResult?
    @Published public var cleaningProgressText: String = ""
    
    private let scanEngine: ScanEngine
    private let cleanupEngine: CleanupEngine
    private var scanTask: Task<Void, Never>?
    
    public init(
        scanEngine: ScanEngine = .shared,
        cleanupEngine: CleanupEngine = .shared
    ) {
        self.scanEngine = scanEngine
        self.cleanupEngine = cleanupEngine
        self.selectedCategories = Set(ScanCategory.allCases.filter { $0.isDefaultSmartScan })
        self.expandedCategories = self.selectedCategories
    }
    
    /// Starts an asynchronous scan across all selected categories.
    public func startScan() {
        guard !isScanning else { return }
        
        isScanning = true
        hasCompletedScan = false
        scanResult = ScanResult()
        progress = nil
        
        let categoriesToScan = Array(selectedCategories)
        
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            let engine = self.scanEngine
            let result = await engine.scan(categories: categoriesToScan) { [weak self] currentProgress in
                Task { @MainActor [weak self] in
                    self?.progress = currentProgress
                }
            }
            
            if !Task.isCancelled {
                self.scanResult = result
                self.hasCompletedScan = true
                self.expandedCategories = Set(categoriesToScan)
            }
            self.isScanning = false
        }
    }
    
    /// Cancels any active running scan.
    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }
    
    /// Toggles the selection state for an individual discovered item.
    public func toggleItemSelection(_ item: ScannedItem) {
        guard var items = scanResult.itemsByCategory[item.category],
              let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].isSelected.toggle()
        scanResult.itemsByCategory[item.category] = items
    }
    
    /// Toggles all items within a category simultaneously.
    public func toggleAllItems(in category: ScanCategory, select: Bool) {
        guard var items = scanResult.itemsByCategory[category] else { return }
        for index in items.indices {
            if category.isHighRisk && select {
                continue
            }
            items[index].isSelected = select
        }
        scanResult.itemsByCategory[category] = items
    }
    
    /// Toggles category disclosure expansion.
    public func toggleExpansion(for category: ScanCategory) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }
    
    /// Prompts the confirmation sheet before proceeding with deletion.
    public func promptReview() {
        guard !scanResult.selectedItems.isEmpty else { return }
        showConfirmationSheet = true
    }
    
    /// Executes the safe cleanup of all confirmed selected items.
    public func executeCleanup(
        userExclusions: Set<String> = [],
        autoEmptyTrash: Bool = false,
        permanentDelete: Bool = false,
        onSuccess: (@MainActor @Sendable () -> Void)? = nil
    ) {
        let itemsToClean = scanResult.selectedItems
        guard !itemsToClean.isEmpty else { return }
        
        isCleaning = true
        showConfirmationSheet = false
        cleaningProgressText = "Moving items to Trash..."
        
        let engine = cleanupEngine
        
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let executionResult = try await engine.clean(
                    items: itemsToClean,
                    userExclusions: userExclusions,
                    autoEmptyTrash: autoEmptyTrash,
                    permanentDelete: permanentDelete
                ) { [weak self] count, bytes in
                    Task { @MainActor [weak self] in
                        self?.cleaningProgressText = "Cleaned \(count) files (\(ByteFormatter.format(bytes)) freed)"
                    }
                }
                
                self.lastCleanupResult = executionResult
                self.showResultSheet = true
                
                let cleanedIDs = Set(itemsToClean.map { $0.id })
                for (cat, items) in self.scanResult.itemsByCategory {
                    self.scanResult.itemsByCategory[cat] = items.filter { !cleanedIDs.contains($0.id) }
                }
                
                onSuccess?()
            } catch {
                // Handled gracefully
            }
            
            self.isCleaning = false
        }
    }
}
