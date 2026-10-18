import Foundation

/// Service for persisting and managing cleanup session logs and historical metrics.
public final class HistoryService: Sendable {
    public static let shared = HistoryService()
    
    private let storageURL: URL
    
    public init(customStorageURL: URL? = nil) {
        if let url = customStorageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/CleanMac")
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            self.storageURL = appSupport.appendingPathComponent("history.json")
        }
    }
    
    /// Loads all past cleanup reports sorted chronologically from newest to oldest.
    public func loadReports() -> [CleanupReport] {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let reports = try? JSONDecoder().decode([CleanupReport].self, from: data) else {
            return []
        }
        return reports.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Records a new cleanup session report.
    public func recordReport(_ report: CleanupReport) {
        var existing = loadReports()
        existing.insert(report, at: 0)
        saveReports(existing)
    }
    
    /// Marks a session report as undone.
    public func markUndone(reportId: UUID) {
        var existing = loadReports()
        if let index = existing.firstIndex(where: { $0.id == reportId }) {
            existing[index].isUndone = true
            saveReports(existing)
        }
    }
    
    /// Cumulative bytes freed across all sessions.
    public func totalBytesFreed() -> Int64 {
        loadReports().reduce(0) { $0 + ($1.isUndone ? 0 : $1.bytesFreed) }
    }
    
    /// Clears the history logs.
    public func clearHistory() {
        try? FileManager.default.removeItem(at: storageURL)
    }
    
    private func saveReports(_ reports: [CleanupReport]) {
        if let data = try? JSONEncoder().encode(reports) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}
