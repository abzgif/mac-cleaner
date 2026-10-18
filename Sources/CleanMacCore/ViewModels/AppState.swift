import SwiftUI
import Combine

/// Root application state coordinator managing navigation, disk telemetry, and shared engine references.
@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedTab: NavigationTab = .dashboard
    @Published public var diskUsage: DiskUsage
    @Published public var totalHistoricalFreedBytes: Int64 = 0
    @Published public var statusAlertMessage: String?
    @Published public var showStatusAlert: Bool = false
    
    public let scanEngine: ScanEngine
    public let cleanupEngine: CleanupEngine
    public let historyService: HistoryService
    public let diskSpaceService: DiskSpaceService
    public let safetyPolicy: SafetyPolicy
    
    public init(
        scanEngine: ScanEngine = .shared,
        cleanupEngine: CleanupEngine = .shared,
        historyService: HistoryService = .shared,
        diskSpaceService: DiskSpaceService = .shared,
        safetyPolicy: SafetyPolicy = .shared
    ) {
        self.scanEngine = scanEngine
        self.cleanupEngine = cleanupEngine
        self.historyService = historyService
        self.diskSpaceService = diskSpaceService
        self.safetyPolicy = safetyPolicy
        self.diskUsage = diskSpaceService.getDiskUsage()
        self.totalHistoricalFreedBytes = historyService.totalBytesFreed()
    }
    
    /// Refreshes current disk usage from macOS kernel.
    public func refreshDiskUsage() {
        self.diskUsage = diskSpaceService.getDiskUsage()
        self.totalHistoricalFreedBytes = historyService.totalBytesFreed()
    }
    
    /// Presents a non-blocking toast/banner alert.
    public func presentAlert(message: String) {
        self.statusAlertMessage = message
        self.showStatusAlert = true
    }
}
