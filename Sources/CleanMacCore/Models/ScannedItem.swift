import Foundation

/// Represents an individual file or directory discovered during a scan.
public struct ScannedItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let url: URL
    public let path: String
    public let displayName: String
    public let size: Int64
    public let category: ScanCategory
    public let modificationDate: Date?
    public var isSelected: Bool
    public var accessError: String?
    public var duplicateGroupId: String?
    public var parentAppName: String?
    public var riskWarning: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        displayName: String? = nil,
        size: Int64,
        category: ScanCategory,
        modificationDate: Date? = nil,
        isSelected: Bool = true,
        accessError: String? = nil,
        duplicateGroupId: String? = nil,
        parentAppName: String? = nil,
        riskWarning: String? = nil
    ) {
        self.id = id
        self.url = url
        self.path = url.path
        self.displayName = displayName ?? url.lastPathComponent
        self.size = size
        self.category = category
        self.modificationDate = modificationDate
        self.isSelected = isSelected
        self.accessError = accessError
        self.duplicateGroupId = duplicateGroupId
        self.parentAppName = parentAppName
        self.riskWarning = riskWarning
    }
    
    /// Formatted human-readable size for display.
    public var formattedSize: String {
        ByteFormatter.format(size)
    }
}
