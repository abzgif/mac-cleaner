import Foundation

/// Defines the primary navigation sections in the CleanMac sidebar.
public enum NavigationTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case dashboard = "dashboard"
    case smartScan = "smart_scan"
    case spaceAnalyzer = "space_analyzer"
    case largeOldFiles = "large_old_files"
    case duplicates = "duplicates"
    case appUninstaller = "app_uninstaller"
    case startupItems = "startup_items"
    case maintenance = "maintenance"
    case history = "history"
    case settings = "settings"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .smartScan: return "Smart Scan"
        case .spaceAnalyzer: return "Space Lens"
        case .largeOldFiles: return "Large & Old Files"
        case .duplicates: return "Duplicates"
        case .appUninstaller: return "App Uninstaller"
        case .startupItems: return "Startup Items"
        case .maintenance: return "Maintenance"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "gauge.with.needle"
        case .smartScan: return "sparkles"
        case .spaceAnalyzer: return "chart.pie"
        case .largeOldFiles: return "clock.arrow.circlepath"
        case .duplicates: return "doc.on.doc"
        case .appUninstaller: return "trash.circle"
        case .startupItems: return "bolt.shield"
        case .maintenance: return "wrench.and.screwdriver"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }
}
