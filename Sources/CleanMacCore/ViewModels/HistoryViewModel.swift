import Foundation
import SwiftUI
import Combine

/// ViewModel managing past cleanup sessions, audit logs, and restore/undo capabilities.
@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var reports: [CleanupReport] = []
    @Published public var totalFreedBytes: Int64 = 0
    @Published public var undoStatusMessage: String?
    @Published public var showClearConfirmation: Bool = false
    
    private let historyService: HistoryService
    private let cleanupEngine: CleanupEngine
    
    public init(
        historyService: HistoryService = .shared,
        cleanupEngine: CleanupEngine = .shared
    ) {
        self.historyService = historyService
        self.cleanupEngine = cleanupEngine
        refresh()
    }
    
    public func refresh() {
        self.reports = historyService.loadReports()
        self.totalFreedBytes = historyService.totalBytesFreed()
    }
    
    public func undo(report: CleanupReport) {
        let success = cleanupEngine.undo(report: report)
        if success {
            undoStatusMessage = "Successfully restored files to your Desktop from Trash."
        } else {
            undoStatusMessage = "Could not restore: items were permanently deleted or already cleared from Trash."
        }
        refresh()
    }
    
    public func clearAllHistory() {
        historyService.clearHistory()
        refresh()
    }
}
