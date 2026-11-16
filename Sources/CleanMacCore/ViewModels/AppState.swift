import SwiftUI
import Combine

/// Root application state coordinator managing navigation, live disk telemetry, and shared engine references.
@MainActor
public final class AppState: ObservableObject {
    @Published public var selectedTab: NavigationTab = .smartScan
    @Published public var diskUsage: DiskUsage
    @Published public var totalHistoricalFreedBytes: Int64 = 0
    @Published public var statusAlertMessage: String?
    @Published public var showStatusAlert: Bool = false
    
    public let scanEngine: ScanEngine
    public let cleanupEngine: CleanupEngine
    public let historyService: HistoryService
    public let diskSpaceService: DiskSpaceService
    public let safetyPolicy: SafetyPolicy
    
    private var cancellables = Set<AnyCancellable>()
    
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
        
        // Automatically refresh storage telemetry whenever any cleanup or uninstall completes
        NotificationCenter.default.publisher(for: .cleanMacDidUpdateStorage)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshDiskUsage()
                // Follow-up refresh after APFS finishes asynchronous block reclamation
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self?.refreshDiskUsage()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Refreshes current disk usage from macOS kernel.
    public func refreshDiskUsage() {
        let previousTotal = self.totalHistoricalFreedBytes
        let updatedTotal = historyService.totalBytesFreed()
        let newlyFreedDelta = max(0, updatedTotal - previousTotal)
        
        let kernelUsage = diskSpaceService.getDiskUsage()
        
        // If APFS hasn't flushed the newly freed blocks into statvfs yet, reflect at least the newly freed delta immediately
        if newlyFreedDelta > 0 && kernelUsage.freeBytes <= self.diskUsage.freeBytes {
            let adjustedFree = min(kernelUsage.totalBytes, self.diskUsage.freeBytes + newlyFreedDelta)
            self.diskUsage = DiskUsage(totalBytes: kernelUsage.totalBytes, freeBytes: adjustedFree)
        } else {
            self.diskUsage = kernelUsage
        }
        
        self.totalHistoricalFreedBytes = updatedTotal
    }
    
    /// Presents a non-blocking toast/banner alert.
    public func presentAlert(message: String) {
        self.statusAlertMessage = message
        self.showStatusAlert = true
    }
}
