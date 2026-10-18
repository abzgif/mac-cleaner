import Foundation
import AppKit

/// Represents an installed macOS application along with its associated support files, caches, and preferences.
public struct AppItem: Identifiable, Sendable {
    public let id: String // Bundle ID or path
    public let bundleIdentifier: String?
    public let name: String
    public let bundleURL: URL
    public let appSize: Int64
    public var relatedItems: [ScannedItem]
    public var isSelected: Bool
    public let isSystemApp: Bool
    public let modificationDate: Date?
    
    public init(
        bundleIdentifier: String?,
        name: String,
        bundleURL: URL,
        appSize: Int64,
        relatedItems: [ScannedItem] = [],
        isSelected: Bool = false,
        isSystemApp: Bool = false,
        modificationDate: Date? = nil
    ) {
        self.id = bundleIdentifier ?? bundleURL.path
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.bundleURL = bundleURL
        self.appSize = appSize
        self.relatedItems = relatedItems
        self.isSelected = isSelected
        self.isSystemApp = isSystemApp
        self.modificationDate = modificationDate
    }
    
    /// Total size of the app binary plus all its associated data files.
    public var totalSize: Int64 {
        appSize + relatedItems.reduce(0) { $0 + $1.size }
    }
    
    public var formattedTotalSize: String {
        ByteFormatter.format(totalSize)
    }
    
    public var formattedAppSize: String {
        ByteFormatter.format(appSize)
    }
    
    /// Apps consuming more than 500 MB of disk space.
    public var isLarge: Bool {
        totalSize >= 500 * 1024 * 1024
    }
    
    /// Apps not modified or accessed in more than 90 days.
    public var isUnused: Bool {
        guard let modDate = modificationDate else { return false }
        let ninetyDaysAgo = Date().addingTimeInterval(-90 * 86400)
        return modDate < ninetyDaysAgo
    }
    
    // MARK: - Sub-groupings of associated residual files
    
    public var supportItems: [ScannedItem] {
        relatedItems.filter { $0.path.contains("/Application Support/") }
    }
    
    public var preferenceItems: [ScannedItem] {
        relatedItems.filter { $0.path.contains("/Preferences/") }
    }
    
    public var cacheItems: [ScannedItem] {
        relatedItems.filter { $0.path.contains("/Caches/") || $0.path.contains("/Logs/") }
    }
    
    public var containerItems: [ScannedItem] {
        relatedItems.filter { $0.path.contains("/Containers/") || $0.path.contains("/Group Containers/") }
    }
    
    public var stateItems: [ScannedItem] {
        relatedItems.filter { $0.path.contains("/Saved Application State/") }
    }
    
    public var otherItems: [ScannedItem] {
        let known = Set(supportItems.map(\.id) + preferenceItems.map(\.id) + cacheItems.map(\.id) + containerItems.map(\.id) + stateItems.map(\.id))
        return relatedItems.filter { !known.contains($0.id) }
    }
}
