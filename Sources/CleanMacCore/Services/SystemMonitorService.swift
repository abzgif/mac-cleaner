import Foundation
import Darwin

/// Service interfacing with Darwin Mach kernel APIs for real-time CPU, RAM, and memory purging.
public final class SystemMonitorService: Sendable {
    public static let shared = SystemMonitorService()
    
    private final class CPUSampleState: @unchecked Sendable {
        var prevUser: UInt64 = 0
        var prevSystem: UInt64 = 0
        var prevIdle: UInt64 = 0
        var prevNice: UInt64 = 0
        var hasSample: Bool = false
        let lock = NSLock()
    }
    
    private let cpuState = CPUSampleState()
    
    public init() {
        if let initial = readRawCPUTicks() {
            cpuState.lock.lock()
            cpuState.prevUser = initial.user
            cpuState.prevSystem = initial.system
            cpuState.prevIdle = initial.idle
            cpuState.prevNice = initial.nice
            cpuState.hasSample = true
            cpuState.lock.unlock()
        }
    }
    
    /// Queries the Mach kernel for precise physical memory metrics matching macOS Activity Monitor.
    public func getMemoryStats() -> MemoryStats {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return MemoryStats(totalBytes: total, usedBytes: 0, freeBytes: total)
        }
        
        let pageSize = UInt64(getpagesize())
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let purgeable = UInt64(vmStats.purgeable_count) * pageSize
        let internalPages = UInt64(vmStats.internal_page_count) * pageSize
        let externalPages = UInt64(vmStats.external_page_count) * pageSize
        let freePages = UInt64(vmStats.free_count) * pageSize
        
        // Exact Apple Activity Monitor calculation:
        // App Memory = internal_page_count - purgeable_count
        let appMemory = (internalPages > purgeable) ? (internalPages - purgeable) : internalPages
        let used = appMemory + wired + compressed
        let cached = purgeable + externalPages
        let free = (total > used) ? (total - used) : freePages
        
        // Query kernel memory pressure level: 1 = normal, 2 = warning, 4 = critical
        var pressureLevel: Int32 = 1
        var size = MemoryLayout<Int32>.size
        _ = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0)
        
        return MemoryStats(
            totalBytes: total,
            usedBytes: used,
            freeBytes: free,
            appMemoryBytes: appMemory,
            wiredBytes: wired,
            compressedBytes: compressed,
            cachedBytes: cached,
            pressureLevel: pressureLevel
        )
    }
    
    /// Queries processor info and calculates delta CPU load across all physical/efficiency cores.
    public func getCPUStats() -> CPUStats {
        guard let current = readRawCPUTicks() else {
            return CPUStats(userRatio: 0.05, systemRatio: 0.03, idleRatio: 0.92)
        }
        
        cpuState.lock.lock()
        defer { cpuState.lock.unlock() }
        
        guard cpuState.hasSample else {
            cpuState.prevUser = current.user
            cpuState.prevSystem = current.system
            cpuState.prevIdle = current.idle
            cpuState.prevNice = current.nice
            cpuState.hasSample = true
            return CPUStats(userRatio: 0.05, systemRatio: 0.03, idleRatio: 0.92)
        }
        
        let deltaUser = current.user >= cpuState.prevUser ? (current.user - cpuState.prevUser) : 0
        let deltaSystem = current.system >= cpuState.prevSystem ? (current.system - cpuState.prevSystem) : 0
        let deltaIdle = current.idle >= cpuState.prevIdle ? (current.idle - cpuState.prevIdle) : 0
        let deltaNice = current.nice >= cpuState.prevNice ? (current.nice - cpuState.prevNice) : 0
        
        cpuState.prevUser = current.user
        cpuState.prevSystem = current.system
        cpuState.prevIdle = current.idle
        cpuState.prevNice = current.nice
        
        let deltaTotal = Double(deltaUser + deltaSystem + deltaIdle + deltaNice)
        guard deltaTotal > 0 else {
            return CPUStats(userRatio: 0, systemRatio: 0, idleRatio: 1.0)
        }
        
        return CPUStats(
            userRatio: Double(deltaUser + deltaNice) / deltaTotal,
            systemRatio: Double(deltaSystem) / deltaTotal,
            idleRatio: Double(deltaIdle) / deltaTotal
        )
    }
    
    private func readRawCPUTicks() -> (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)? {
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
            return nil
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
        
        return (totalUser, totalSystem, totalIdle, totalNice)
    }
    
    /// Safely purges inactive memory and system disk caches to free RAM.
    /// Returns the bytes of memory freed during the operation.
    public func purgeInactiveRAM() async -> Int64 {
        let before = getMemoryStats().freeBytes
        
        // 1. Run system purge tool via Process if available
        let task = Process()
        task.launchPath = "/usr/sbin/purge"
        try? task.run()
        task.waitUntilExit()
        
        // 2. Small async delay to let kernel page tables settle
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let after = getMemoryStats().freeBytes
        return max(0, Int64(after) - Int64(before))
    }
}
