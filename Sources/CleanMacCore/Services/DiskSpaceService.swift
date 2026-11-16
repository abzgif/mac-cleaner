import Foundation

/// Notification posted whenever CleanMac finishes a cleanup, uninstall, or restore operation so UI storage gauges update immediately.
public extension Notification.Name {
    static let cleanMacDidUpdateStorage = Notification.Name("cleanMacDidUpdateStorage")
}

/// Service for monitoring real-time system disk storage capacity and availability.
public final class DiskSpaceService: Sendable {
    public static let shared = DiskSpaceService()
    
    public init() {}
    
    /// Queries the primary root volume (`/`) for total and available byte capacity without Foundation URL caching.
    public func getDiskUsage() -> DiskUsage {
        var rootURL = URL(fileURLWithPath: "/")
        rootURL.removeAllCachedResourceValues()
        
        // Query uncached kernel statvfs first for instant block-level updates, combined with APFS important usage capacity
        var statFree: Int64 = 0
        var statTotal: Int64 = 0
        var stats = statvfs()
        if statvfs("/", &stats) == 0 {
            statTotal = Int64(stats.f_blocks) * Int64(stats.f_frsize)
            statFree = Int64(stats.f_bavail) * Int64(stats.f_frsize)
        }
        
        do {
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            
            let total = Int64(values.volumeTotalCapacity ?? Int(statTotal))
            let importantFree = values.volumeAvailableCapacityForImportantUsage ?? 0
            let standardFree = Int64(values.volumeAvailableCapacity ?? 0)
            
            // Prefer volumeAvailableCapacity (or statvfs f_bavail) when it updates immediately after file deletion
            let free = standardFree > 0 ? standardFree : (importantFree > 0 ? importantFree : statFree)
            return DiskUsage(totalBytes: total, freeBytes: free)
        } catch {
            return DiskUsage(totalBytes: statTotal, freeBytes: statFree)
        }
    }
}
