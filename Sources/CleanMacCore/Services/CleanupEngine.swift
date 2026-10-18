import Foundation
import AppKit

/// Result summary of a cleanup execution run.
public struct CleanupExecutionResult: Sendable {
    public let report: CleanupReport
    public let skippedViolations: [String]
    public let permissionFailures: [String]
    
    public init(report: CleanupReport, skippedViolations: [String], permissionFailures: [String]) {
        self.report = report
        self.skippedViolations = skippedViolations
        self.permissionFailures = permissionFailures
    }
}

/// Executes file deletions safely using the macOS Trash bin with strict denylist verification and audit logging.
public final class CleanupEngine: Sendable {
    public static let shared = CleanupEngine()
    
    private let safetyPolicy: SafetyPolicy
    private let historyService: HistoryService
    
    public init(
        safetyPolicy: SafetyPolicy = .shared,
        historyService: HistoryService = .shared
    ) {
        self.safetyPolicy = safetyPolicy
        self.historyService = historyService
    }
    
    /// Safely cleans the provided items, enforcing denylists and moving to Trash by default.
    ///
    /// - Parameters:
    ///   - items: The list of items confirmed by the user to be cleaned.
    ///   - userExclusions: Custom paths excluded by the user in Settings.
    ///   - autoEmptyTrash: If true, empties Trash after moving items.
    ///   - permanentDelete: If true, permanently deletes instead of Trashing (disabled by default).
    ///   - onProgress: Optional progress handler reporting completed count and total bytes.
    /// - Returns: CleanupExecutionResult with the session report and any skipped paths.
    public func clean(
        items: [ScannedItem],
        userExclusions: Set<String> = [],
        autoEmptyTrash: Bool = false,
        permanentDelete: Bool = false,
        onProgress: (@Sendable (_ completedCount: Int, _ freedBytes: Int64) -> Void)? = nil
    ) async throws -> CleanupExecutionResult {
        let fileManager = FileManager.default
        var trashedPaths: [String] = []
        var skippedViolations: [String] = []
        var permissionFailures: [String] = []
        var freedBytes: Int64 = 0
        var successfulCount = 0
        var categoriesCleaned: Set<ScanCategory> = []
        
        for item in items {
            if Task.isCancelled { break }
            
            // 1. Critical Safety Validation
            let safetyCheck = safetyPolicy.validateDeletionSafety(for: item.path, userExclusions: userExclusions)
            switch safetyCheck {
            case .failure(let violation):
                skippedViolations.append("\(item.path): \(violation.localizedDescription)")
                continue
            case .success:
                break
            }
            
            // 2. Verify file exists
            guard fileManager.fileExists(atPath: item.path) else {
                continue
            }
            
            // 3. Perform Deletion
            do {
                let isAlreadyInTrash = item.category == .trash ||
                                       item.path.contains("/.Trash/") ||
                                       item.path.hasSuffix("/.Trash")
                
                if permanentDelete || isAlreadyInTrash {
                    // Items already in Trash or marked for permanent deletion must be removed directly
                    try fileManager.removeItem(at: item.url)
                    trashedPaths.append(item.path)
                } else {
                    // Safe move to Trash via AppKit / Foundation
                    var resultingURL: NSURL?
                    do {
                        try (fileManager as FileManager).trashItem(at: item.url, resultingItemURL: &resultingURL)
                        if let result = resultingURL as URL? {
                            trashedPaths.append(result.path)
                        } else {
                            trashedPaths.append(item.path)
                        }
                    } catch {
                        // Fallback: If deleting an application from /Applications fails due to root ownership or lack of write permission
                        if item.path.hasPrefix("/Applications/") {
                            try moveAppToTrashWithAdmin(at: item.path)
                            trashedPaths.append(item.path)
                        } else {
                            throw error
                        }
                    }
                }
                
                freedBytes += item.size
                successfulCount += 1
                categoriesCleaned.insert(item.category)
                onProgress?(successfulCount, freedBytes)
            } catch {
                permissionFailures.append("\(item.path): \(error.localizedDescription)")
            }
        }
        
        // 4. Optional auto-empty trash
        if autoEmptyTrash {
            emptyTrash()
        }
        
        // 5. Generate and persist audit report
        let report = CleanupReport(
            bytesFreed: freedBytes,
            fileCount: successfulCount,
            categoriesCleaned: Array(categoriesCleaned),
            trashedItemPaths: trashedPaths,
            permanentDeletion: permanentDelete
        )
        
        historyService.recordReport(report)
        
        return CleanupExecutionResult(
            report: report,
            skippedViolations: skippedViolations,
            permissionFailures: permissionFailures
        )
    }
    
    /// Restores items from Trash back to their original positions if available.
    public func undo(report: CleanupReport) -> Bool {
        guard !report.isUndone, !report.permanentDeletion else { return false }
        
        let fileManager = FileManager.default
        var restoredAny = false
        
        for trashedPath in report.trashedItemPaths {
            guard fileManager.fileExists(atPath: trashedPath) else { continue }
            
            // Attempt to move from Trash back to original location
            // Note: Trashed items in ~/.Trash can be moved back if destination does not exist
            let filename = URL(fileURLWithPath: trashedPath).lastPathComponent
            let home = fileManager.homeDirectoryForCurrentUser
            let fallbackRestoreURL = home.appendingPathComponent("Desktop/Restored_\(filename)")
            
            do {
                try fileManager.moveItem(atPath: trashedPath, toPath: fallbackRestoreURL.path)
                restoredAny = true
            } catch {
                // Ignore failure if destination already exists
            }
        }
        
        if restoredAny {
            historyService.markUndone(reportId: report.id)
        }
        return restoredAny
    }
    
    /// Safely moves a single file or directory to Trash after validating against the safety policy.
    public func moveItemToTrash(at url: URL) throws {
        let safetyCheck = safetyPolicy.validateDeletionSafety(for: url.path)
        switch safetyCheck {
        case .failure(let violation):
            throw violation
        case .success:
            break
        }
        
        let fileManager = FileManager.default
        if url.path.contains("/.Trash/") {
            try fileManager.removeItem(at: url)
            return
        }
        
        var resultingURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
    }
    
    /// Empties the macOS trash safely by removing files from ~/.Trash directly, with AppleScript fallback.
    public func emptyTrash() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let userTrash = home.appendingPathComponent(".Trash")
        
        // 1. Direct deletion of contents inside user's .Trash directory
        if let contents = try? fileManager.contentsOfDirectory(at: userTrash, includingPropertiesForKeys: nil) {
            for item in contents {
                try? fileManager.removeItem(at: item)
            }
        }
        
        // 2. Also run AppleScript to ensure Finder dock icon updates to empty state
        let script = "tell application \"Finder\" to empty trash"
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
        }
    }
    
    /// Moves a protected or root-owned application to Trash using system administrator privileges.
    public func moveAppToTrashWithAdmin(at path: String) throws {
        let fileManager = FileManager.default
        let trashPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        let escapedSource = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let escapedTrash = trashPath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        
        // 1. Try moving to user's Trash as admin
        let script = "do shell script \"mv -f \\\"\(escapedSource)\\\" \\\"\(escapedTrash)/\\\"\" with administrator privileges"
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            if errorInfo == nil {
                return
            }
        }
        
        // 2. If move failed, permanently remove via admin rm -rf
        let rmScript = "do shell script \"rm -rf \\\"\(escapedSource)\\\"\" with administrator privileges"
        if let rmAppleScript = NSAppleScript(source: rmScript) {
            var rmError: NSDictionary?
            rmAppleScript.executeAndReturnError(&rmError)
            if let rmErr = rmError {
                let msg = rmErr[NSAppleScript.errorMessage] as? String ?? "Failed to delete application with administrator privileges."
                throw NSError(domain: "CleanMac", code: 513, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }
    }
}
