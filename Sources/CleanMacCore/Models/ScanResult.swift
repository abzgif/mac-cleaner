import Foundation

/// Aggregated result of a scan containing all discovered items grouped by category.
public struct ScanResult: Sendable {
    public var itemsByCategory: [ScanCategory: [ScannedItem]]
    public var inaccessiblePaths: [String]
    public var scanDuration: TimeInterval
    
    public init(
        itemsByCategory: [ScanCategory: [ScannedItem]] = [:],
        inaccessiblePaths: [String] = [],
        scanDuration: TimeInterval = 0
    ) {
        self.itemsByCategory = itemsByCategory
        self.inaccessiblePaths = inaccessiblePaths
        self.scanDuration = scanDuration
    }
    
    /// All items flattened across all categories.
    public var allItems: [ScannedItem] {
        itemsByCategory.values.flatMap { $0 }
    }
    
    /// Only items currently marked as selected for cleanup.
    public var selectedItems: [ScannedItem] {
        allItems.filter { $0.isSelected }
    }
    
    /// Total bytes of all discovered items.
    public var totalSize: Int64 {
        allItems.reduce(0) { $0 + $1.size }
    }
    
    /// Total bytes of currently selected items.
    public var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }
    
    /// Human-readable total size string.
    public var formattedTotalSize: String {
        ByteFormatter.format(totalSize)
    }
    
    /// Human-readable selected size string.
    public var formattedSelectedSize: String {
        ByteFormatter.format(selectedSize)
    }
    
    /// Returns items for a specific category.
    public func items(for category: ScanCategory) -> [ScannedItem] {
        itemsByCategory[category] ?? []
    }
    
    /// Returns total size for a specific category.
    public func size(for category: ScanCategory) -> Int64 {
        items(for: category).reduce(0) { $0 + $1.size }
    }
    
    /// Returns selected size for a specific category.
    public func selectedSize(for category: ScanCategory) -> Int64 {
        items(for: category).filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
}
