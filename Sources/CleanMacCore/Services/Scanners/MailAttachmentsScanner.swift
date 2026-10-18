import Foundation

/// Scans Apple Mail downloaded attachments and offline cached files.
public final class MailAttachmentsScanner: Scannable, Sendable {
    public let category: ScanCategory = .mailAttachments
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        var results: [ScannedItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let mailTargets = [
            home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
            home.appendingPathComponent("Library/Mail Downloads")
        ]
        
        for dir in mailTargets {
            if Task.isCancelled { break }
            guard fileManager.fileExists(atPath: dir.path),
                  fileManager.isReadableFile(atPath: dir.path) else { continue }
            
            let contents = (try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            
            for itemURL in contents {
                if Task.isCancelled { break }
                let size = ScannerHelper.size(of: itemURL)
                guard size > 1024 * 10 else { continue }
                
                let modDate = ScannerHelper.modificationDate(of: itemURL)
                let item = ScannedItem(
                    url: itemURL,
                    displayName: "Mail Attachment: \(itemURL.lastPathComponent)",
                    size: size,
                    category: category,
                    modificationDate: modDate,
                    isSelected: false, // Default unchecked for safety
                    riskWarning: "Downloaded Mail attachment copy"
                )
                results.append(item)
                onFoundItem?(item)
            }
        }
        
        return results
    }
}
