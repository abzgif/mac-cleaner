import Foundation
import AppKit

/// Defines safety violations when an operation attempts to access or modify a protected path.
public enum SafetyViolation: LocalizedError, Equatable {
    case protectedSystemPath(String)
    case protectedUserDirectory(String)
    case activeRunningApplication(String)
    case userExcludedPath(String)
    case rootOrEmptyPath
    case invalidPath(String)
    
    public var errorDescription: String? {
        switch self {
        case .protectedSystemPath(let path):
            return "Safety Violation: Path is a protected macOS system component (\(path))."
        case .protectedUserDirectory(let path):
            return "Safety Violation: Path is an essential personal user directory (\(path))."
        case .activeRunningApplication(let path):
            return "Safety Violation: Cannot modify an application or support file while it is running (\(path))."
        case .userExcludedPath(let path):
            return "Safety Violation: Path is in your personal exclusion list (\(path))."
        case .rootOrEmptyPath:
            return "Safety Violation: Path is root ('/') or empty."
        case .invalidPath(let path):
            return "Safety Violation: Invalid or non-normalized file path (\(path))."
        }
    }
}

/// Enforces non-negotiable system safety rules, hardcoded denylists, and active application protection.
public final class SafetyPolicy: Sendable {
    public static let shared = SafetyPolicy()
    
    /// Hardcoded system prefixes that must NEVER be deleted.
    public static let hardcodedSystemDenylist: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/etc",
        "/private/etc",
        "/private/var/db",
        "/private/var/protected",
        "/private/var/root",
        "/var/root",
        "/Library/Apple",
        "/Library/CoreAnalytics",
        "/Library/SystemExtensions",
        "/Library/Preferences/SystemConfiguration",
        "/Library/Security",
        "/Library/Keychains",
        "/dev",
        "/net",
        "/home",
        "/Volumes"
    ]
    
    /// Essential user directories that must never be targeted for deletion.
    public static var protectedUserFolderNames: Set<String> {
        [
            "Desktop",
            "Documents",
            "Pictures",
            "Movies",
            "Music",
            ".ssh",
            ".gnupg",
            ".aws",
            "Library/Keychains",
            "Library/Mail",
            "Library/Messages",
            "Library/Photos",
            "Library/IdentityServices",
            "Library/Accounts"
        ]
    }
    
    public init() {}
    
    /// Checks whether a given path is safe to delete.
    ///
    /// - Parameters:
    ///   - rawPath: The path to check.
    ///   - userExclusions: Optional set of paths added by the user to exclude.
    /// - Returns: Success if safe, or a SafetyViolation error.
    public func validateDeletionSafety(
        for rawPath: String,
        userExclusions: Set<String> = []
    ) -> Result<Void, SafetyViolation> {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "/" else {
            return .failure(.rootOrEmptyPath)
        }
        
        // Canonicalize path and resolve any symbolic links to prevent traversal bypasses
        let standardURL = URL(fileURLWithPath: trimmed).standardized
        let resolvedPath = standardURL.resolvingSymlinksInPath().path
        let candidatePaths = [trimmed, standardURL.path, resolvedPath]
        
        // 1. Check Hardcoded System Denylist across all path representations
        for testPath in candidatePaths {
            for systemPath in Self.hardcodedSystemDenylist {
                if testPath == systemPath || testPath.hasPrefix(systemPath + "/") {
                    return .failure(.protectedSystemPath(testPath))
                }
            }
        }
        
        // 2. Check Home Directory & Critical User Directories
        let homeURL = FileManager.default.homeDirectoryForCurrentUser.standardized
        let homePath = homeURL.resolvingSymlinksInPath().path
        
        if resolvedPath == homePath {
            return .failure(.protectedUserDirectory(resolvedPath))
        }
        
        for protectedFolder in Self.protectedUserFolderNames {
            let protectedPath = (homeURL.appendingPathComponent(protectedFolder).standardized).resolvingSymlinksInPath().path
            if resolvedPath == protectedPath {
                return .failure(.protectedUserDirectory(resolvedPath))
            }
        }
        
        // 3. Check User Custom Exclusions
        for exclusion in userExclusions {
            let standardizedExclusion = URL(fileURLWithPath: exclusion).standardized.resolvingSymlinksInPath().path
            if resolvedPath == standardizedExclusion || resolvedPath.hasPrefix(standardizedExclusion + "/") {
                return .failure(.userExcludedPath(resolvedPath))
            }
        }
        
        // 4. Check Currently Running Applications
        if isBelongingToRunningApp(path: resolvedPath) {
            return .failure(.activeRunningApplication(resolvedPath))
        }
        
        return .success(())
    }
    
    /// Determines whether the path belongs to an active, currently-running process.
    public func isBelongingToRunningApp(path: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleURL = app.bundleURL?.standardized.resolvingSymlinksInPath() else {
                continue
            }
            if path == bundleURL.path || path.hasPrefix(bundleURL.path + "/") {
                return true
            }
            
            // Also protect active app's container / Application Support if bundleIdentifier matches
            if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
                if path.localizedCaseInsensitiveContains(bundleID) &&
                   (path.contains("/Application Support/") || path.contains("/Containers/")) {
                    return true
                }
            }
        }
        return false
    }
}
