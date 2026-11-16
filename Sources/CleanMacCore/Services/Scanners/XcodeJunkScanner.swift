import Foundation

/// Scans Xcode DerivedData, iOS DeviceSupport, and Simulator caches without touching package manager repositories.
public final class XcodeJunkScanner: Scannable, Sendable {
    public let category: ScanCategory = .xcodeJunk
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let developerTargets: [(name: String, base: URL, expandSubdirs: Bool)] = [
            ("Xcode DerivedData", home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), true),
            ("iOS DeviceSupport", home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), true),
            ("watchOS DeviceSupport", home.appendingPathComponent("Library/Developer/Xcode/watchOS DeviceSupport"), true),
            ("Simulator Caches", home.appendingPathComponent("Library/Developer/CoreSimulator/Caches"), false)
        ]
        
        for target in developerTargets {
            guard fileManager.fileExists(atPath: target.base.path),
                  fileManager.isReadableFile(atPath: target.base.path) else { continue }
            
            if target.expandSubdirs {
                let subdirs = (try? fileManager.contentsOfDirectory(
                    at: target.base,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                
                for itemURL in subdirs {
                    if Task.isCancelled { break }
                    
                    let size = ScannerHelper.size(of: itemURL)
                    guard size > 1024 * 1024 else { continue }
                    
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
        
        return results.sorted { $0.size > $1.size }
    }
}
