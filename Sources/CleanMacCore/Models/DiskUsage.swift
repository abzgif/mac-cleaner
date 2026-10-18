import Foundation

/// Snapshot of the primary system disk storage usage.
public struct DiskUsage: Sendable {
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let usedBytes: Int64
    
    public init(totalBytes: Int64, freeBytes: Int64) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.usedBytes = max(0, totalBytes - freeBytes)
    }
    
    /// Ratio of used disk space between 0.0 and 1.0.
    public var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    /// Ratio of free disk space between 0.0 and 1.0.
    public var freeRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }
    
    public var formattedTotal: String {
        ByteFormatter.format(totalBytes)
    }
    
    public var formattedFree: String {
        ByteFormatter.format(freeBytes)
    }
    
    public var formattedUsed: String {
        ByteFormatter.format(usedBytes)
    }
}
