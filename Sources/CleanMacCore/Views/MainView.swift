import SwiftUI

/// Root application view hosting NavigationSplitView with sidebar and detail view switching.
public struct MainView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 290)
        } detail: {
            detailContent
                .background(.ultraThinMaterial)
        }
        .frame(minWidth: 920, minHeight: 620)
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView()
        case .smartScan:
            SmartScanView()
        case .spaceAnalyzer:
            SpaceAnalyzerView()
        case .maintenance:
            MaintenanceView()
        case .startupItems:
            StartupItemsView()
        case .largeOldFiles:
            LargeOldFilesView()
        case .duplicates:
            DuplicateFinderView()
        case .appUninstaller:
            AppUninstallerView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}
