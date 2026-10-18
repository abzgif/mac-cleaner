import Foundation

/// Progress state emitted during a file system scan.
public struct ScanProgress: Sendable {
    public let currentCategory: ScanCategory
    public let statusMessage: String
    public let itemsFoundCount: Int
    public let bytesFound: Int64
    public let progressFraction: Double
    
    public init(
        currentCategory: ScanCategory,
        statusMessage: String,
        itemsFoundCount: Int,
        bytesFound: Int64,
        progressFraction: Double
    ) {
        self.currentCategory = currentCategory
        self.statusMessage = statusMessage
        self.itemsFoundCount = itemsFoundCount
        self.bytesFound = bytesFound
        self.progressFraction = progressFraction
    }
}

/// Orchestrates multi-category filesystem scans with async streaming and cancellation.
public final class ScanEngine: Sendable {
    public static let shared = ScanEngine()
    
    private let scanners: [ScanCategory: any Scannable]
    
    public init(scanners: [ScanCategory: any Scannable]? = nil) {
        if let custom = scanners {
            self.scanners = custom
        } else {
            self.scanners = [
                .systemCaches: SystemCachesScanner(),
                .userLogs: UserLogsScanner(),
                .appLeftovers: AppLeftoversScanner(),
                .browserCaches: BrowserCachesScanner(),
                .xcodeJunk: XcodeJunkScanner(),
                .developerPackages: DeveloperEcosystemScanner(),
                .mailAttachments: MailAttachmentsScanner(),
                .downloads: DownloadsScanner(),
                .trash: TrashScanner(),
                .languageFiles: LanguageFilesScanner(),
                .largeOldFiles: LargeOldFilesScanner(),
                .duplicates: DuplicateFinderScanner()
            ]
        }
    }
    
    /// Executes a scan for the specified categories, streaming live progress without blocking.
    ///
    /// - Parameters:
    ///   - categories: The set of categories to scan.
    ///   - onProgress: Live progress reporting closure called as items are found.
    /// - Returns: Aggregated ScanResult.
    public func scan(
        categories: [ScanCategory],
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> ScanResult {
        let startTime = Date()
        var itemsByCategory: [ScanCategory: [ScannedItem]] = [:]
        var inaccessiblePaths: [String] = []
        var totalItemsCount = 0
        var totalBytesCount: Int64 = 0
        
        let totalCategories = max(1, categories.count)
        
        for (index, category) in categories.enumerated() {
            if Task.isCancelled { break }
            
            guard let scanner = scanners[category] else { continue }
            
            let baseFraction = Double(index) / Double(totalCategories)
            onProgress?(
                ScanProgress(
                    currentCategory: category,
                    statusMessage: "Scanning \(category.title)...",
                    itemsFoundCount: totalItemsCount,
                    bytesFound: totalBytesCount,
                    progressFraction: baseFraction
                )
            )
            
            do {
                let items = try await scanner.scan { [totalItemsCount, totalBytesCount] item in
                    let currentCount = totalItemsCount + 1
                    let currentBytes = totalBytesCount + item.size
                    onProgress?(
                        ScanProgress(
                            currentCategory: category,
                            statusMessage: "Analyzing: \(item.displayName)",
                            itemsFoundCount: currentCount,
                            bytesFound: currentBytes,
                            progressFraction: baseFraction + (0.8 / Double(totalCategories))
                        )
                    )
                }
                
                // Track inaccessible files or errors
                for item in items {
                    if let error = item.accessError {
                        inaccessiblePaths.append("\(item.path): \(error)")
                    }
                }
                
                itemsByCategory[category] = items
                totalItemsCount += items.count
                totalBytesCount += items.reduce(0) { $0 + $1.size }
            } catch {
                inaccessiblePaths.append("Category \(category.title): \(error.localizedDescription)")
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return ScanResult(
            itemsByCategory: itemsByCategory,
            inaccessiblePaths: inaccessiblePaths,
            scanDuration: duration
        )
    }
}
