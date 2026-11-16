import Foundation
import AppKit

/// Defines safety violations when an operation attempts to access or modify a protected path.
public enum SafetyViolation: LocalizedError, Equatable {
    case protectedSystemPath(String)
    case protectedUserDirectory(String)
    case protectedApplicationData(String)
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
        case .protectedApplicationData(let path):
            return "Safety Violation: Path contains critical application data (\(path))."
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
        "/Library/Application Support",
        "/Library/Preferences",
        "/dev",
        "/net",
        "/home",
        "/Volumes"
    ]
    
    /// Essential user directories that must never be targeted for deletion as a whole.
    public static var protectedUserFolderNames: Set<String> {
        [
            "Desktop",
            "Documents",
            "Downloads",
            "Pictures",
            "Movies",
            "Music",
            "Applications",
            ".ssh",
            ".gnupg",
            ".aws",
            ".kube",
            "Library",
            "Library/Application Support",
            "Library/Preferences",
            "Library/Caches",
            "Library/Logs",
            "Library/Containers",
            "Library/Group Containers",
            "Library/Keychains",
            "Library/Mail",
            "Library/Messages",
            "Library/Photos",
            "Library/IdentityServices",
            "Library/Accounts",
            "Library/LaunchAgents"
        ]
    }
    
    /// Critical application and IDE runtime cache identifiers that must NOT be wiped by general SystemCachesScanner
    /// because deleting them breaks self-updating apps (like JDownloader 2) or wipes IDE indexes (like Android Studio).
    public static let protectedCacheIdentifiers: [String] = [
        // JDownloader 2 & Java install4j launchers
        "jdownloader",
        "org.jdownloader",
        "install4j",
        "jd2",
        // Android Studio & JetBrains IDE internal index/settings caches
        "androidstudio",
        "com.google.android",
        "jetbrains",
        "com.jetbrains",
        // Essential macOS services & iCloud state in ~/Library/Caches
        "com.apple.launchservices",
        "cloudkit",
        "com.apple.bird",
        "com.apple.icloud",
        "com.apple.nsurlsessiond",
        "com.apple.accountsd",
        "com.apple.homed",
        "com.apple.ap.adprivacyd",
        "com.apple.parsecd",
        "geoservices",
        "familycircle",
        "passkit"
    ]
    
    public init() {}
    
    /// Checks whether a given path is safe to delete.
    public func validateDeletionSafety(
        for rawPath: String,
        userExclusions: Set<String> = [],
        isAppUninstall: Bool = false
    ) -> Result<Void, SafetyViolation> {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "/" else {
            return .failure(.rootOrEmptyPath)
        }
        
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
        
        // 2. Never allow modifying files INSIDE an .app bundle (e.g., .lproj, .jar, Contents/Resources)
        for testPath in candidatePaths {
            if testPath.contains(".app/") {
                return .failure(.protectedApplicationData(testPath))
            }
        }
        
        // 3. Check Home Directory & Critical User Directories
        let homeURL = FileManager.default.homeDirectoryForCurrentUser.standardized
        let homePath = homeURL.resolvingSymlinksInPath().path
        
        if resolvedPath == homePath || resolvedPath == "/Applications" || resolvedPath == "/Users" || resolvedPath == "/Library" {
            return .failure(.protectedUserDirectory(resolvedPath))
        }
        
        for protectedFolder in Self.protectedUserFolderNames {
            let protectedPath = (homeURL.appendingPathComponent(protectedFolder).standardized).resolvingSymlinksInPath().path
            if resolvedPath == protectedPath {
                return .failure(.protectedUserDirectory(resolvedPath))
            }
        }
        
        // Always protect personal communication/credential subtrees
        let strictlyProtectedSubtrees = [
            ".ssh",
            ".gnupg",
            "Library/Keychains",
            "Library/Mail",
            "Library/Messages",
            "Library/Photos",
            "Library/IdentityServices",
            "Library/Accounts"
        ]
        for subtree in strictlyProtectedSubtrees {
            let subtreePath = (homeURL.appendingPathComponent(subtree).standardized).resolvingSymlinksInPath().path
            if resolvedPath == subtreePath || resolvedPath.hasPrefix(subtreePath + "/") {
                return .failure(.protectedUserDirectory(resolvedPath))
            }
        }
        
        // 4. Unless explicitly uninstalling a specific app, protect Application Support, Preferences,
        // and critical IDE / JDownloader runtime caches.
        if !isAppUninstall {
            let appSupportPath = homeURL.appendingPathComponent("Library/Application Support").standardized.resolvingSymlinksInPath().path
            let prefsPath = homeURL.appendingPathComponent("Library/Preferences").standardized.resolvingSymlinksInPath().path
            let crashReporterPath = homeURL.appendingPathComponent("Library/Application Support/CrashReporter").standardized.resolvingSymlinksInPath().path
            
            if (resolvedPath.hasPrefix(appSupportPath + "/") && !resolvedPath.hasPrefix(crashReporterPath)) ||
               resolvedPath.hasPrefix(prefsPath + "/") {
                return .failure(.protectedApplicationData(resolvedPath))
            }
            
            if isProtectedCacheOrAppPath(resolvedPath) {
                return .failure(.protectedApplicationData(resolvedPath))
            }
        }
        
        // 5. Check User Custom Exclusions
        for exclusion in userExclusions {
            let standardizedExclusion = URL(fileURLWithPath: exclusion).standardized.resolvingSymlinksInPath().path
            if resolvedPath == standardizedExclusion || resolvedPath.hasPrefix(standardizedExclusion + "/") {
                return .failure(.userExcludedPath(resolvedPath))
            }
        }
        
        // 6. Check Currently Running Applications
        if isBelongingToRunningApp(path: resolvedPath) {
            return .failure(.activeRunningApplication(resolvedPath))
        }
        
        return .success(())
    }
    
    /// Checks whether a cache/log path belongs to a protected IDE, download manager, or macOS core service.
    public func isProtectedCacheOrAppPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.contains(".app/") {
            return true
        }
        for identifier in Self.protectedCacheIdentifiers {
            if lower.contains(identifier) {
                return true
            }
        }
        return false
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
            
            if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
                if path.localizedCaseInsensitiveContains(bundleID) &&
                   (path.contains("/Application Support/") || path.contains("/Containers/") || path.contains("/Caches/")) {
                    return true
                }
            }
            if let appName = app.localizedName, appName.count >= 3 {
                let lastComponent = URL(fileURLWithPath: path).lastPathComponent
                if lastComponent.localizedCaseInsensitiveContains(appName) &&
                   (path.contains("/Application Support/") || path.contains("/Caches/")) {
                    return true
                }
            }
        }
        return false
    }
}
