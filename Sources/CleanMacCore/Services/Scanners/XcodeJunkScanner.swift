import Foundation

/// Scans developer artifacts including Xcode DerivedData, Archives, iOS DeviceSupport, and simulator caches.
public final class XcodeJunkScanner: Scannable, Sendable {
    public let category: ScanCategory = .xcodeJunk
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let developerTargets: [(name: String, base: URL, expandSubdirs: Bool)] = [
            ("Xcode DerivedData", home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), true),
            ("Xcode Archives", home.appendingPathComponent("Library/Developer/Xcode/Archives"), true),
            ("iOS DeviceSupport", home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), true),
            ("watchOS DeviceSupport", home.appendingPathComponent("Library/Developer/Xcode/watchOS DeviceSupport"), true),
            ("Simulator Caches", home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"), false),
            ("Xcode Module Caches", home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"), false),
            ("CocoaPods Cache", home.appendingPathComponent("Library/Caches/CocoaPods"), false),
            ("SPM Artifacts Cache", home.appendingPathComponent("Library/Caches/org.swift.swiftpm"), false)
        ]
        
        for target in developerTargets {
            guard fileManager.fileExists(atPath: target.base.path),
                  fileManager.isReadableFile(atPath: target.base.path) else { continue }
            
            if target.expandSubdirs {
                // List individual projects/devices so user can selectively delete specific DerivedData folders
                let subdirs = (try? fileManager.contentsOfDirectory(
                    at: target.base,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                
                for itemURL in subdirs {
                    if Task.isCancelled { break }
                    
                    let size = ScannerHelper.size(of: itemURL)
                    guard size > 1024 * 1024 else { continue } // > 1MB
                    
                    let modDate = ScannerHelper.modificationDate(of: itemURL)
                    let item = ScannedItem(
                        url: itemURL,
                        displayName: "\(target.name): \(itemURL.lastPathComponent)",
                        size: size,
                        category: category,
                        modificationDate: modDate,
                        isSelected: true
                    )
                    results.append(item)
                    onFoundItem?(item)
                }
            } else {
                let size = ScannerHelper.size(of: target.base)
                guard size > 1024 * 1024 else { continue }
                
                let modDate = ScannerHelper.modificationDate(of: target.base)
                let item = ScannedItem(
                    url: target.base,
                    displayName: target.name,
                    size: size,
                    category: category,
                    modificationDate: modDate,
                    isSelected: true
                )
                results.append(item)
                onFoundItem?(item)
            }
        }
        
        return results
    }
}
