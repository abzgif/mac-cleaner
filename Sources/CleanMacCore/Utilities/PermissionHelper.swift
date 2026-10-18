import Foundation
import AppKit

/// Helper for verifying file permissions, Full Disk Access, and opening System Settings.
public enum PermissionHelper {
    
    /// Checks if the application currently has Full Disk Access (FDA).
    /// Typically verified by checking read access to user data like Safari metadata or TCC protected folders.
    public static var hasFullDiskAccess: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let testURL = home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        if let handle = try? FileHandle(forReadingFrom: testURL) {
            try? handle.close()
            return true
        }
        let dirURL = home.appendingPathComponent("Library/Safari")
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: dirURL.path), !contents.isEmpty {
            return true
        }
        return false
    }
    
    /// Checks if a specific path is readable.
    public static func isReadable(path: String) -> Bool {
        return FileManager.default.isReadableFile(atPath: path)
    }
    
    /// Checks if a specific path is writable.
    public static func isWritable(path: String) -> Bool {
        return FileManager.default.isWritableFile(atPath: path)
    }
    
    /// Opens macOS System Settings directly to Privacy & Security > Full Disk Access.
    @MainActor
    public static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Prompts the user to choose or grant access to a folder using an NSOpenPanel with a security-scoped bookmark.
    @MainActor
    public static func promptForDirectoryAccess(
        message: String = "CleanMac needs permission to scan this folder to find junk files.",
        prompt: String = "Grant Access"
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = message
        panel.prompt = prompt
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
