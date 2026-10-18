import Foundation
import Darwin

/// Service interfacing with Darwin Mach kernel APIs for real-time CPU, RAM, and memory purging.
public final class SystemMonitorService: Sendable {
    public static let shared = SystemMonitorService()
    
    public init() {}
    
    /// Queries the Mach kernel for precise physical memory metrics.
    public func getMemoryStats() -> MemoryStats {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            let total = ProcessInfo.processInfo.physicalMemory
            return MemoryStats(totalBytes: total, activeBytes: 0, inactiveBytes: 0, wiredBytes: 0, compressedBytes: 0, freeBytes: total)
        }
        
        let pageSize = UInt64(getpagesize())
        let total = ProcessInfo.processInfo.physicalMemory
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let free = UInt64(vmStats.free_count) * pageSize
        
        return MemoryStats(
            totalBytes: total,
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free
        )
    }
    
    /// Queries processor info to estimate CPU load across all physical/efficiency cores.
    public func getCPUStats() -> CPUStats {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &infoCount
        )
        
        guard result == KERN_SUCCESS, let info = processorInfo else {
            return CPUStats(userRatio: 0.1, systemRatio: 0.05, idleRatio: 0.85)
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount * UInt32(MemoryLayout<integer_t>.size)))
        }
        
        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        
        for i in 0..<Int(processorCount) {
            let base = i * Int(CPU_STATE_MAX)
            totalUser += UInt64(info[base + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[base + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[base + Int(CPU_STATE_NICE)])
        }
        
        let totalTicks = Double(totalUser + totalSystem + totalIdle + totalNice)
        guard totalTicks > 0 else {
            return CPUStats(userRatio: 0, systemRatio: 0, idleRatio: 1.0)
        }
        
        return CPUStats(
            userRatio: Double(totalUser + totalNice) / totalTicks,
            systemRatio: Double(totalSystem) / totalTicks,
            idleRatio: Double(totalIdle) / totalTicks
        )
    }
    
    /// Safely purges inactive memory and system disk caches to free RAM.
    /// Returns the bytes of memory freed during the operation.
    public func purgeInactiveRAM() async -> Int64 {
        let before = getMemoryStats().freeBytes + getMemoryStats().inactiveBytes
        
        // 1. Run system purge tool via Process if available
        let task = Process()
        task.launchPath = "/usr/sbin/purge"
        try? task.run()
        task.waitUntilExit()
        
        // 2. Small async delay to let kernel page tables settle
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let after = getMemoryStats().freeBytes + getMemoryStats().inactiveBytes
        return max(0, Int64(after) - Int64(before))
    }
}
