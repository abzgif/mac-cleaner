import Foundation

/// Service for monitoring real-time system disk storage capacity and availability.
public final class DiskSpaceService: Sendable {
    public static let shared = DiskSpaceService()
    
    public init() {}
    
    /// Queries the primary root volume (`/`) for total and available byte capacity.
    public func getDiskUsage() -> DiskUsage {
        let rootURL = URL(fileURLWithPath: "/")
        
        do {
            let values = try rootURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
            
            return DiskUsage(totalBytes: total, freeBytes: free)
        } catch {
            // Fallback via statvfs if resourceValues fails
            var stats = statvfs()
            if statvfs("/", &stats) == 0 {
                let total = Int64(stats.f_blocks) * Int64(stats.f_frsize)
                let free = Int64(stats.f_bavail) * Int64(stats.f_frsize)
                return DiskUsage(totalBytes: total, freeBytes: free)
            }
            return DiskUsage(totalBytes: 0, freeBytes: 0)
        }
    }
}
