import Foundation

/// Service responsible for running safe system maintenance and repair scripts.
public final class MaintenanceService: Sendable {
    public static let shared = MaintenanceService()
    
    public init() {}
    
    /// Default list of available maintenance tasks.
    public func getAvailableTasks() -> [MaintenanceTask] {
        return [
            MaintenanceTask(
                id: "ram_purge",
                title: "Free Inactive RAM",
                subtitle: "Instructs macOS virtual memory manager to reclaim purgeable and inactive pages.",
                iconName: "memorychip",
                category: "Memory",
                isSelected: true
            ),
            MaintenanceTask(
                id: "flush_dns",
                title: "Flush DNS Cache",
                subtitle: "Flushes the local resolver cache to resolve connectivity issues and update DNS records.",
                iconName: "network",
                category: "Network",
                isSelected: true
            ),
            MaintenanceTask(
                id: "launch_services",
                title: "Rebuild Launch Services Database",
                subtitle: "Fixes duplicate or incorrect 'Open With' application entries and restores broken file icons.",
                iconName: "square.split.2x2",
                category: "System",
                isSelected: false
            ),
            MaintenanceTask(
                id: "font_cache",
                title: "Clear User Font Cache",
                subtitle: "Cleans macOS font database caches to fix corrupted typography or missing system glyphs.",
                iconName: "textformat",
                category: "System",
                isSelected: false
            ),
            MaintenanceTask(
                id: "quicklook_cache",
                title: "Reset Quick Look Cache",
                subtitle: "Flushes Quick Look generator caches and thumbnail generator daemons.",
                iconName: "eye.circle",
                category: "System",
                isSelected: false
            ),
            MaintenanceTask(
                id: "empty_trash",
                title: "Empty Trash Bin",
                subtitle: "Permanently clears all contents from macOS Trash on all local drives.",
                iconName: "trash.fill",
                category: "Storage",
                isSelected: true
            )
        ]
    }
    
    /// Executes a single maintenance task by ID and returns a status summary string.
    public func executeTask(id: String) async -> (success: Bool, message: String) {
        switch id {
        case "ram_purge":
            let freed = await SystemMonitorService.shared.purgeInactiveRAM()
            let formatted = ByteFormatter.format(freed)
            return (true, "Reclaimed approximately \(formatted) of inactive memory pages.")
            
        case "flush_dns":
            let _ = await runProcess(path: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
            let _ = await runProcess(path: "/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
            return (true, "DNS cache flushed and mDNSResponder refreshed.")
            
        case "launch_services":
            let lsRegisterPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            if FileManager.default.fileExists(atPath: lsRegisterPath) {
                let res = await runProcess(path: lsRegisterPath, arguments: ["-kill", "-r", "-domain", "local", "-domain", "user"])
                return (res.exitCode == 0, "LaunchServices database rebuild request issued.")
            } else {
                return (false, "LaunchServices tool not found on this macOS release.")
            }
            
        case "font_cache":
            let res = await runProcess(path: "/usr/bin/atsutil", arguments: ["databases", "-removeUser"])
            return (res.exitCode == 0, "User font caches cleared. Changes will take effect on next app launch.")
            
        case "quicklook_cache":
            let _ = await runProcess(path: "/usr/bin/qlmanage", arguments: ["-r", "cache"])
            let _ = await runProcess(path: "/usr/bin/qlmanage", arguments: ["-r"])
            return (true, "Quick Look thumbnail server and generators reset.")
            
        case "empty_trash":
            CleanupEngine.shared.emptyTrash()
            return (true, "macOS Trash bin emptied successfully.")
            
        default:
            return (false, "Unknown maintenance task.")
        }
    }
    
    // MARK: - Process Execution
    
    private func runProcess(path: String, arguments: [String]) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (process.terminationStatus, output))
                } catch {
                    continuation.resume(returning: (-1, error.localizedDescription))
                }
            }
        }
    }
}
