import Foundation

/// Service for discovering, parsing, and managing macOS LaunchAgents and LaunchDaemons.
public final class StartupItemsService: Sendable {
    public static let shared = StartupItemsService()
    
    public init() {}
    
    /// Scans user and system launch configuration directories.
    public func scanStartupItems() -> [StartupItem] {
        var items: [StartupItem] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        let locations: [(type: StartupItemType, dir: URL)] = [
            (.userAgent, home.appendingPathComponent("Library/LaunchAgents")),
            (.systemAgent, URL(fileURLWithPath: "/Library/LaunchAgents")),
            (.systemDaemon, URL(fileURLWithPath: "/Library/LaunchDaemons"))
        ]
        
        for location in locations {
            guard fileManager.fileExists(atPath: location.dir.path),
                  fileManager.isReadableFile(atPath: location.dir.path) else { continue }
            
            let files = (try? fileManager.contentsOfDirectory(at: location.dir, includingPropertiesForKeys: nil)) ?? []
            
            for fileURL in files where fileURL.pathExtension == "plist" {
                // Parse property list
                guard let data = try? Data(contentsOf: fileURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                    continue
                }
                
                let label = plist["Label"] as? String ?? fileURL.deletingPathExtension().lastPathComponent
                let runAtLoad = plist["RunAtLoad"] as? Bool ?? false
                
                // Extract target executable path
                var programPath: String? = plist["Program"] as? String
                if programPath == nil, let args = plist["ProgramArguments"] as? [String], let firstArg = args.first {
                    programPath = firstArg
                }
                
                // Check if target binary actually exists on disk
                var isOrphaned = false
                if let prog = programPath {
                    // Check if program exists
                    if !fileManager.fileExists(atPath: prog) {
                        isOrphaned = true
                    }
                }
                
                let displayName = label
                    .replacingOccurrences(of: "com.", with: "")
                    .replacingOccurrences(of: "org.", with: "")
                    .replacingOccurrences(of: "net.", with: "")
                
                let item = StartupItem(
                    id: fileURL.path,
                    name: displayName,
                    label: label,
                    path: fileURL,
                    programPath: programPath,
                    runAtLoad: runAtLoad,
                    isOrphaned: isOrphaned,
                    itemType: location.type,
                    isSelected: isOrphaned // Auto-select orphaned items for cleanup
                )
                items.append(item)
            }
        }
        
        // Sort: orphaned items first, then by name
        return items.sorted {
            if $0.isOrphaned != $1.isOrphaned {
                return $0.isOrphaned && !$1.isOrphaned
            }
            return $0.name < $1.name
        }
    }
    
    /// Unloads and removes selected startup configuration files to Trash.
    public func removeItems(_ items: [StartupItem]) -> [String] {
        var errors: [String] = []
        let fileManager = FileManager.default
        
        for item in items {
            // Unload agent via launchctl
            let process = Process()
            process.launchPath = "/bin/launchctl"
            process.arguments = ["unload", "-w", item.path.path]
            try? process.run()
            process.waitUntilExit()
            
            // Move plist to Trash
            do {
                try fileManager.trashItem(at: item.path, resultingItemURL: nil)
            } catch {
                errors.append("\(item.name): \(error.localizedDescription)")
            }
        }
        
        return errors
    }
}
