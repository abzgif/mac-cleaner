import Foundation

/// Scans safe user cache directories (~/Library/Caches) while strictly preserving IDEs (Android Studio, JetBrains),
/// self-updating apps (JDownloader 2), package manager stores, and core Apple services.
public final class SystemCachesScanner: Scannable, Sendable {
    public let category: ScanCategory = .systemCaches
    
    /// Browser cache folder names handled separately by BrowserCachesScanner.
    private static let browserCacheFolders: Set<String> = [
        "com.apple.safari",
        "google",
        "firefox",
        "microsoft edge",
        "bravesoftware",
        "company.thebrowser.browser"
    ]
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // Only scan the user's ~/Library/Caches directory (never system-wide /Library/Caches)
        let baseDir = home.appendingPathComponent("Library/Caches")
        guard fileManager.fileExists(atPath: baseDir.path),
              fileManager.isReadableFile(atPath: baseDir.path) else {
            return results
        }
        
        let contents = (try? fileManager.contentsOfDirectory(
            at: baseDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        
        for itemURL in contents {
            if Task.isCancelled { break }
            
            let nameLower = itemURL.lastPathComponent.lowercased()
            
            // 1. Skip browser caches (managed by BrowserCachesScanner)
            if Self.browserCacheFolders.contains(nameLower) {
                continue
            }
            
            // 2. Skip Xcode/SwiftPM/CocoaPods/Homebrew caches (managed by developer scanners)
            if nameLower == "com.apple.dt.xcode" ||
               nameLower == "org.swift.swiftpm" ||
               nameLower == "cocoapods" ||
               nameLower == "homebrew" {
                continue
            }
            
            // 3. Never touch protected apps/IDEs (JDownloader 2, Android Studio, JetBrains, Gradle, Apple system services)
            if SafetyPolicy.shared.isProtectedCacheOrAppPath(itemURL.path) {
                continue
            }
            
            // 4. Never delete running application caches
            if SafetyPolicy.shared.isBelongingToRunningApp(path: itemURL.path) {
                continue
            }
            
            // 5. Validate against full SafetyPolicy
            if case .failure = SafetyPolicy.shared.validateDeletionSafety(for: itemURL.path) {
                continue
            }
            
            let size = ScannerHelper.size(of: itemURL)
            guard size > 1024 * 100 else { continue } // Skip sub-100KB noise
            
            let modDate = ScannerHelper.modificationDate(of: itemURL)
            let item = ScannedItem(
                url: itemURL,
                displayName: itemURL.lastPathComponent,
                size: size,
                category: category,
                modificationDate: modDate,
                isSelected: true
            )
            results.append(item)
            onFoundItem?(item)
        }
        
        return results.sorted { $0.size > $1.size }
    }
}
