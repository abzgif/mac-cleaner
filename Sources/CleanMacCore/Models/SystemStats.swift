import Foundation
import Darwin

/// Snapshot of system physical memory allocation and pressure.
public struct MemoryStats: Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let appMemoryBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let cachedBytes: UInt64
    public let pressureLevel: Int32
    
    public init(
        totalBytes: UInt64,
        usedBytes: UInt64,
        freeBytes: UInt64,
        appMemoryBytes: UInt64 = 0,
        wiredBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        cachedBytes: UInt64 = 0,
        pressureLevel: Int32 = 1
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.appMemoryBytes = appMemoryBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.cachedBytes = cachedBytes
        self.pressureLevel = pressureLevel
    }
    
    /// Memory utilization ratio between 0.0 and 1.0.
    public var pressureRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    public var formattedTotal: String { ByteFormatter.formatMemory(totalBytes) }
    public var formattedUsed: String { ByteFormatter.formatMemory(usedBytes) }
    public var formattedFree: String { ByteFormatter.formatMemory(freeBytes) }
    public var formattedAppMemory: String { ByteFormatter.formatMemory(appMemoryBytes) }
    public var formattedWired: String { ByteFormatter.formatMemory(wiredBytes) }
    public var formattedCompressed: String { ByteFormatter.formatMemory(compressedBytes) }
    public var formattedCached: String { ByteFormatter.formatMemory(cachedBytes) }
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
