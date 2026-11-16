import Foundation

/// Scans Android SDK components (System Images, NDKs, Platforms, Build-Tools, AVDs, SDK Caches)
/// as well as Gradle, Maven, Homebrew, NPM, Yarn, PNPM, Bun, Pip, UV, Cargo, and Go caches.
/// Individual SDK versions/images are listed separately so the user can choose which SDKs to clean.
public final class DeveloperEcosystemScanner: Scannable, Sendable {
    public let category: ScanCategory = .developerPackages
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. Expandable SDK directories (lists each version/image individually, unchecked by default so user chooses which SDKs to remove)
        let expandableSDKTargets: [(prefix: String, base: URL, selectByDefault: Bool)] = [
            ("Android SDK System Image", home.appendingPathComponent("Library/Android/sdk/system-images"), false),
            ("Android NDK", home.appendingPathComponent("Library/Android/sdk/ndk"), false),
            ("Android SDK Platform", home.appendingPathComponent("Library/Android/sdk/platforms"), false),
            ("Android SDK Build-Tools", home.appendingPathComponent("Library/Android/sdk/build-tools"), false),
            ("Android Virtual Device (AVD)", home.appendingPathComponent(".android/avd"), false),
            ("Gradle Wrapper Dist", home.appendingPathComponent(".gradle/wrapper/dists"), false)
        ]
        
        for target in expandableSDKTargets {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath: target.base.path),
                  fileManager.isReadableFile(atPath: target.base.path) else { continue }
            
            let subdirs = (try? fileManager.contentsOfDirectory(
                at: target.base,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for itemURL in subdirs {
                if Task.isCancelled { break }
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 * 1024 else { continue } // > 1 MB
                
                let modDate = ScannerHelper.modificationDate(of: itemURL)
                let item = ScannedItem(
                    url: itemURL,
                    displayName: "\(target.prefix): \(itemURL.lastPathComponent)",
                    size: size,
                    category: category,
                    modificationDate: modDate,
                    isSelected: target.selectByDefault,
                    riskWarning: target.selectByDefault ? nil : "SDK Component"
                )
                results.append(item)
                onFoundItem?(item)
            }
        }
        
        // 2. Developer & SDK Build/Download Caches (safe to clean to reclaim space)
        let cacheTargets: [(name: String, path: URL, selectByDefault: Bool)] = [
            ("Android SDK Temp Downloads", home.appendingPathComponent("Library/Android/sdk/.temp"), true),
            ("Android SDK Download Intermediates", home.appendingPathComponent("Library/Android/sdk/.downloadIntermediates"), true),
            ("Android Build & Tool Cache", home.appendingPathComponent(".android/cache"), true),
            ("Android Build Cache", home.appendingPathComponent(".android/build-cache"), true),
            ("Gradle Build Caches", home.appendingPathComponent(".gradle/caches"), false),
            ("Gradle Daemon Logs", home.appendingPathComponent(".gradle/daemon"), true),
            ("Maven Repository Cache", home.appendingPathComponent(".m2/repository"), false),
            ("Homebrew Downloads Cache", home.appendingPathComponent("Library/Caches/Homebrew"), true),
            ("NPM Cache", home.appendingPathComponent(".npm/_cacache"), true),
            ("Yarn Cache", home.appendingPathComponent("Library/Caches/Yarn"), true),
            ("PNPM Store", home.appendingPathComponent("Library/pnpm/store"), false),
            ("Bun Install Cache", home.appendingPathComponent(".bun/install/cache"), true),
            ("Python Pip Cache", home.appendingPathComponent("Library/Caches/pip"), true),
            ("Python UV Cache", home.appendingPathComponent(".cache/uv"), true),
            ("Rust Cargo Registry Cache", home.appendingPathComponent(".cargo/registry/cache"), true),
            ("Go Modules Cache", home.appendingPathComponent("go/pkg/mod/cache"), true),
            ("CocoaPods Cache", home.appendingPathComponent("Library/Caches/CocoaPods"), true),
            ("SwiftPM Artifacts Cache", home.appendingPathComponent("Library/Caches/org.swift.swiftpm"), true)
        ]
        
        for tool in cacheTargets {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath: tool.path.path),
                  fileManager.isReadableFile(atPath: tool.path.path) else { continue }
            
            let size = ScannerHelper.size(of: tool.path)
            guard size > 1024 * 1024 else { continue } // > 1 MB
            
            let modDate = ScannerHelper.modificationDate(of: tool.path)
            let item = ScannedItem(
                url: tool.path,
                displayName: tool.name,
                size: size,
                category: category,
                modificationDate: modDate,
                isSelected: tool.selectByDefault,
                riskWarning: tool.selectByDefault ? nil : "Dependency Cache"
            )
            results.append(item)
            onFoundItem?(item)
        }
        
        return results.sorted { $0.size > $1.size }
    }
}
