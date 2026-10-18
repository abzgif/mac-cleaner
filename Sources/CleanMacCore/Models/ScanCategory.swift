import Foundation

/// Defines all categories of system junk, caches, logs, and files that CleanMac can scan.
public enum ScanCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case systemCaches = "system_caches"
    case userLogs = "user_logs"
    case appLeftovers = "app_leftovers"
    case browserCaches = "browser_caches"
    case xcodeJunk = "xcode_junk"
    case developerPackages = "developer_packages"
    case mailAttachments = "mail_attachments"
    case downloads = "downloads"
    case trash = "trash"
    case languageFiles = "language_files"
    case largeOldFiles = "large_old_files"
    case duplicates = "duplicates"
    
    public var id: String { rawValue }
    
    /// User-facing display title for the category.
    public var title: String {
        switch self {
        case .systemCaches: return "System Caches"
        case .userLogs: return "User Logs & Crash Reports"
        case .appLeftovers: return "App Leftovers"
        case .browserCaches: return "Browser Caches"
        case .xcodeJunk: return "Xcode Developer Junk"
        case .developerPackages: return "Package Manager Caches"
        case .mailAttachments: return "Mail Downloads & Attachments"
        case .downloads: return "Downloads & Old Installers"
        case .trash: return "System Trash"
        case .languageFiles: return "Unused Language Files"
        case .largeOldFiles: return "Large & Old Files"
        case .duplicates: return "Duplicate Files"
        }
    }
    
    /// Description explaining what files this category contains and why they are safe or unsafe to delete.
    public var description: String {
        switch self {
        case .systemCaches:
            return "Temporary system and user cache files that can safely be regenerated when needed."
        case .userLogs:
            return "Application diagnostic logs, diagnostic reports, and crash logs accumulated over time."
        case .appLeftovers:
            return "Orphaned preferences, application support data, and cached assets left behind by uninstalled apps."
        case .browserCaches:
            return "Cached web assets, temporary page previews, and browser download caches (Safari, Chrome, Firefox, Edge)."
        case .xcodeJunk:
            return "Xcode DerivedData, legacy archives, old iOS device support symbols, and simulator cache files."
        case .developerPackages:
            return "Package and build caches from Homebrew, Docker, NPM, Yarn, PNPM, Bun, Pip, UV, Cargo, and Go."
        case .mailAttachments:
            return "Copies of email attachments and temporary preview files downloaded by Apple Mail."
        case .downloads:
            return "Old downloaded files and installer disk images (.dmg, .pkg) that have not been opened recently."
        case .trash:
            return "Items sitting in the macOS Trash bin consuming physical storage space."
        case .languageFiles:
            return "Localization bundles (.lproj) inside third-party apps for languages you do not use. (Advanced / Opt-in)"
        case .largeOldFiles:
            return "Individual files larger than 50 MB that have not been accessed or modified in over 90 days."
        case .duplicates:
            return "Exact duplicate files across your system detected via cryptographic SHA-256 hashing."
        }
    }
    
    /// SF Symbol icon representation for this category.
    public var iconName: String {
        switch self {
        case .systemCaches: return "internaldrive"
        case .userLogs: return "doc.text.magnifyingglass"
        case .appLeftovers: return "shippingbox.and.arrow.backward"
        case .browserCaches: return "globe"
        case .xcodeJunk: return "hammer"
        case .developerPackages: return "cube.box"
        case .mailAttachments: return "envelope.open"
        case .downloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .languageFiles: return "character.book.closed"
        case .largeOldFiles: return "clock.arrow.circlepath"
        case .duplicates: return "doc.on.doc"
        }
    }
    
    /// Indicates whether this category is included by default in Smart Scan.
    public var isDefaultSmartScan: Bool {
        switch self {
        case .systemCaches, .userLogs, .appLeftovers, .browserCaches, .xcodeJunk, .developerPackages, .trash:
            return true
        case .mailAttachments, .downloads, .languageFiles, .largeOldFiles, .duplicates:
            return false
        }
    }
    
    /// Indicates if cleaning this category carries higher risk or requires explicit user opt-in.
    public var isHighRisk: Bool {
        switch self {
        case .languageFiles:
            return true
        default:
            return false
        }
    }
}
