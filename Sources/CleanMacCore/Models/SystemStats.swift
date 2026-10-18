import Foundation
import Darwin

/// Snapshot of system physical memory allocation and pressure.
public struct MemoryStats: Sendable {
    public let totalBytes: UInt64
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let freeBytes: UInt64
    
    public init(
        totalBytes: UInt64,
        activeBytes: UInt64,
        inactiveBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64,
        freeBytes: UInt64
    ) {
        self.totalBytes = totalBytes
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.freeBytes = freeBytes
    }
    
    /// Used memory comprises active, wired, and compressed memory.
    public var usedBytes: UInt64 {
        activeBytes + wiredBytes + compressedBytes
    }
    
    /// Memory pressure ratio between 0.0 and 1.0.
    public var pressureRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    public var formattedTotal: String { ByteFormatter.format(totalBytes) }
    public var formattedUsed: String { ByteFormatter.format(usedBytes) }
    public var formattedFree: String { ByteFormatter.format(freeBytes + inactiveBytes) }
    public var formattedWired: String { ByteFormatter.format(wiredBytes) }
    public var formattedCompressed: String { ByteFormatter.format(compressedBytes) }
    public var formattedActive: String { ByteFormatter.format(activeBytes) }
    public var formattedInactive: String { ByteFormatter.format(inactiveBytes) }
    public var pressurePercentage: Int { Int(pressureRatio * 100) }
}

/// Snapshot of CPU utilization across processor cores.
public struct CPUStats: Sendable {
    public let userRatio: Double
    public let systemRatio: Double
    public let idleRatio: Double
    
    public init(userRatio: Double, systemRatio: Double, idleRatio: Double) {
        self.userRatio = max(0, min(1, userRatio))
        self.systemRatio = max(0, min(1, systemRatio))
        self.idleRatio = max(0, min(1, idleRatio))
    }
    
    public var totalUsedRatio: Double {
        userRatio + systemRatio
    }
    
    public var userPercentage: Int { Int(userRatio * 100) }
    public var systemPercentage: Int { Int(systemRatio * 100) }
    public var totalPercentage: Int { Int(totalUsedRatio * 100) }
}
