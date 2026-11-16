import Foundation

/// Defines the primary navigation sections in the CleanMac sidebar.
public enum NavigationTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case smartScan = "smart_scan"
    case appUninstaller = "app_uninstaller"
    case spaceAnalyzer = "space_analyzer"
    case settings = "settings"
    
    // Legacy cases retained for internal subviews
    case dashboard = "dashboard"
    case largeOldFiles = "large_old_files"
    case duplicates = "duplicates"
    case startupItems = "startup_items"
    case maintenance = "maintenance"
    case history = "history"
    
    public var id: String { rawValue }
    
    /// The streamlined 4 primary tabs shown in the minimal sidebar.
    public static var primaryTabs: [NavigationTab] {
        [.smartScan, .appUninstaller, .spaceAnalyzer, .settings]
    }
    
    public var title: String {
        switch self {
        case .smartScan: return "Smart Clean"
        case .appUninstaller: return "Applications"
        case .spaceAnalyzer: return "Storage Explorer"
        case .settings: return "Settings"
        case .dashboard: return "Overview"
        case .largeOldFiles: return "Large Files"
        case .duplicates: return "Duplicates"
        case .startupItems: return "Startup Items"
        case .maintenance: return "Maintenance"
        case .history: return "History"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .smartScan: return "Caches, logs & trash"
        case .appUninstaller: return "Uninstall apps cleanly"
        case .spaceAnalyzer: return "Folders, large & duplicate files"
        case .settings: return "Exclusions & history"
        default: return ""
        }
    }
    
    public var iconName: String {
        switch self {
        case .smartScan: return "sparkles"
        case .appUninstaller: return "square.grid.2x2"
        case .spaceAnalyzer: return "externaldrive"
        case .settings: return "slider.horizontal.3"
        case .dashboard: return "gauge.with.needle"
        case .largeOldFiles: return "arrow.up.doc"
        case .duplicates: return "doc.on.doc"
        case .startupItems: return "bolt.shield"
        case .maintenance: return "wrench.and.screwdriver"
        case .history: return "clock"
        }
    }
}
