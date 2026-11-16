import Foundation

/// Defines categories of system junk, caches, logs, SDKs, and files that CleanMac can scan.
public enum ScanCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemCaches = "system_caches"
    case browserCaches = "browser_caches"
    case userLogs = "user_logs"
    case trash = "trash"
    case developerPackages = "developer_packages"
    case xcodeJunk = "xcode_junk"
    case downloads = "downloads"
    case appLeftovers = "app_leftovers"
    case mailAttachments = "mail_attachments"
    case languageFiles = "language_files"
    case largeOldFiles = "large_old_files"
    case duplicates = "duplicates"
    
    public var id: String { rawValue }
    
    /// Primary categories displayed in the Smart Clean interface, including SDKs & Developer Caches.
    public static var smartCleanCategories: [ScanCategory] {
        [.systemCaches, .browserCaches, .userLogs, .trash, .developerPackages, .xcodeJunk, .downloads]
    }
    
    /// User-facing display title for the category.
    public var title: String {
        switch self {
        case .systemCaches: return "Application Caches"
        case .browserCaches: return "Browser Caches"
        case .userLogs: return "Logs & Crash Reports"
        case .trash: return "Trash Bin"
        case .developerPackages: return "SDKs & Developer Caches"
        case .xcodeJunk: return "Xcode & Simulator SDKs"
        case .downloads: return "Old Installers (.dmg / .pkg)"
        case .appLeftovers: return "Saved Window States"
        case .mailAttachments: return "Mail Downloads"
        case .languageFiles: return "Unused Language Files"
        case .largeOldFiles: return "Large & Old Files"
        case .duplicates: return "Duplicate Files"
        }
    }
    
    /// Description explaining what files this category contains.
    public var description: String {
        switch self {
        case .systemCaches:
            return "Safe temporary user caches (preserves JDownloader 2, Android Studio IDE state, and active apps)."
        case .browserCaches:
            return "Temporary web media and page caches from closed browsers (preserves logins, history, and bookmarks)."
        case .userLogs:
            return "Diagnostic logs and old crash reports accumulated over time."
        case .trash:
            return "Files sitting in your macOS Trash bin consuming storage space."
        case .developerPackages:
            return "Android SDK platforms, system images, NDKs, AVDs, Gradle, Maven, Homebrew, NPM, Yarn, PNPM, Pip, and Cargo."
        case .xcodeJunk:
            return "Xcode DerivedData, iOS/watchOS DeviceSupport symbols, Simulator caches, SwiftPM, and CocoaPods."
        case .downloads:
            return "Leftover installer disk images (.dmg, .pkg) in your Downloads folder."
        case .appLeftovers:
            return "Orphaned window restoration states (.savedState) from uninstalled apps."
        case .mailAttachments:
            return "Local temporary copies of viewed Apple Mail attachments."
        case .languageFiles:
            return "Disabled for safety to preserve macOS Gatekeeper app signatures."
        case .largeOldFiles:
            return "Files larger than 50 MB not opened in over 90 days."
        case .duplicates:
            return "Byte-for-byte identical files verified via SHA-256 hashing."
        }
    }
    
    /// SF Symbol icon representation for this category.
    public var iconName: String {
        switch self {
        case .systemCaches: return "internaldrive"
        case .browserCaches: return "globe"
        case .userLogs: return "doc.text"
        case .trash: return "trash"
        case .developerPackages: return "cpu"
        case .xcodeJunk: return "hammer"
        case .downloads: return "shippingbox"
        case .appLeftovers: return "macwindow.badge.plus"
        case .mailAttachments: return "envelope.open"
        case .languageFiles: return "character.book.closed"
        case .largeOldFiles: return "arrow.up.doc"
        case .duplicates: return "doc.on.doc"
        }
    }
    
    /// Indicates whether this category is included by default in Smart Clean.
    public var isDefaultSmartScan: Bool {
        switch self {
        case .systemCaches, .browserCaches, .userLogs, .trash, .developerPackages, .xcodeJunk:
            return true
        case .downloads, .appLeftovers, .mailAttachments, .languageFiles, .largeOldFiles, .duplicates:
            return false
        }
    }
    
    /// Indicates whether items in this category should be removed directly to immediately free disk space
    /// rather than moved into ~/.Trash (which keeps the bytes on disk).
    public var deletesDirectlyToFreeSpace: Bool {
        switch self {
        case .systemCaches, .browserCaches, .userLogs, .trash, .developerPackages, .xcodeJunk:
            return true
        case .downloads, .appLeftovers, .mailAttachments, .languageFiles, .largeOldFiles, .duplicates:
            return false
        }
    }
    
    /// Indicates if cleaning this category requires explicit manual item selection.
    public var isHighRisk: Bool {
        switch self {
        case .languageFiles, .downloads:
            return true
        default:
            return false
        }
    }
}
