import Foundation
import SwiftUI
import Combine

/// Data point for historical space freed chart / sparkline.
public struct CleanupHistoryPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let bytesFreed: Int64
    public let label: String
}

/// ViewModel powering the Main Dashboard with circular gauge, hardware meters, and historical trends.
@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public var diskUsage: DiskUsage
    @Published public var recentReports: [CleanupReport] = []
    @Published public var sparklinePoints: [CleanupHistoryPoint] = []
    @Published public var totalFreedBytes: Int64 = 0
    @Published public var memoryStats: MemoryStats
    @Published public var cpuStats: CPUStats
    @Published public var isPurgingRAM: Bool = false
    @Published public var freedRAMMessage: String?
    
    private let diskSpaceService: DiskSpaceService
    private let historyService: HistoryService
    private let monitorService: SystemMonitorService
    private var timer: AnyCancellable?
    
    public init(
        diskSpaceService: DiskSpaceService = .shared,
        historyService: HistoryService = .shared,
        monitorService: SystemMonitorService = .shared
    ) {
        self.diskSpaceService = diskSpaceService
        self.historyService = historyService
        self.monitorService = monitorService
        self.diskUsage = diskSpaceService.getDiskUsage()
        self.memoryStats = monitorService.getMemoryStats()
        self.cpuStats = monitorService.getCPUStats()
        refresh()
        startMonitoring()
    }
    
    
    public func startMonitoring() {
        timer?.cancel()
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateHardwareStats()
            }
    }
    
    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }
    
    public func updateHardwareStats() {
        self.memoryStats = monitorService.getMemoryStats()
        self.cpuStats = monitorService.getCPUStats()
    }
    
    public func refresh() {
        self.diskUsage = diskSpaceService.getDiskUsage()
        self.recentReports = historyService.loadReports()
        self.totalFreedBytes = historyService.totalBytesFreed()
        updateHardwareStats()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        self.sparklinePoints = recentReports.prefix(10).reversed().map { report in
            CleanupHistoryPoint(
                date: report.timestamp,
                bytesFreed: report.bytesFreed,
                label: formatter.string(from: report.timestamp)
            )
        }
    }
    
    public func freeRAM() {
        guard !isPurgingRAM else { return }
        isPurgingRAM = true
        freedRAMMessage = nil
        
        Task { [weak self] in
            guard let self = self else { return }
            let freed = await self.monitorService.purgeInactiveRAM()
            self.updateHardwareStats()
            self.isPurgingRAM = false
            let formatted = ByteFormatter.format(freed)
            self.freedRAMMessage = "Freed \(formatted) of inactive RAM"
        }
    }
}
