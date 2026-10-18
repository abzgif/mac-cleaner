import Foundation

/// Scans developer package managers and toolchain build caches (Homebrew, Docker, NPM, Yarn, PNPM, Bun, Pip, UV, Cargo, Go).
public final class DeveloperEcosystemScanner: Scannable, Sendable {
    public let category: ScanCategory = .developerPackages
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let toolTargets: [(name: String, path: URL)] = [
            ("Homebrew Downloads Cache", home.appendingPathComponent("Library/Caches/Homebrew")),
            ("Homebrew Cask Cache", home.appendingPathComponent("Library/Caches/Homebrew/Cask")),
            ("Docker CLI Cache", home.appendingPathComponent(".docker")),
            ("NPM Cache", home.appendingPathComponent(".npm/_cacache")),
            ("Yarn Cache", home.appendingPathComponent(".yarn/cache")),
            ("Yarn Library Cache", home.appendingPathComponent("Library/Caches/Yarn")),
            ("PNPM Store", home.appendingPathComponent("Library/pnpm/store")),
            ("Bun Install Cache", home.appendingPathComponent(".bun/install/cache")),
            ("Python Pip Cache (User)", home.appendingPathComponent("Library/Caches/pip")),
            ("Python Pip Cache (.cache)", home.appendingPathComponent(".cache/pip")),
            ("Python UV Cache", home.appendingPathComponent(".cache/uv")),
            ("Rust Cargo Registry Cache", home.appendingPathComponent(".cargo/registry/cache")),
            ("Rust Cargo Git DB", home.appendingPathComponent(".cargo/git/db")),
            ("Go Modules Cache", home.appendingPathComponent("go/pkg/mod/cache")),
            ("Gradle Cache", home.appendingPathComponent(".gradle/caches")),
            ("Maven Repository Cache", home.appendingPathComponent(".m2/repository"))
        ]
        
        for tool in toolTargets {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath: tool.path.path) else { continue }
            
            // Skip if belong to active processes
            if SafetyPolicy.shared.isBelongingToRunningApp(path: tool.path.path) {
                continue
            }
            
            guard fileManager.isReadableFile(atPath: tool.path.path) else {
                let errorItem = ScannedItem(
                    url: tool.path,
                    displayName: "\(tool.name) (Restricted)",
                    size: 0,
                    category: category,
                    isSelected: false,
                    accessError: "Access requires additional permission"
                )
                results.append(errorItem)
                onFoundItem?(errorItem)
                continue
            }
            
            let size = ScannerHelper.size(of: tool.path)
            guard size > 1024 * 1024 else { continue } // > 1MB
            
            let modDate = ScannerHelper.modificationDate(of: tool.path)
            let item = ScannedItem(
                url: tool.path,
                displayName: tool.name,
                size: size,
                category: category,
                modificationDate: modDate,
                isSelected: true
            )
            results.append(item)
            onFoundItem?(item)
        }
        
        return results
    }
}
