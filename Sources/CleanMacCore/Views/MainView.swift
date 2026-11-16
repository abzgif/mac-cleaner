import SwiftUI

/// Root application view hosting NavigationSplitView with minimal sidebar and detail view switching.
public struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var updater = AppUpdaterViewModel.shared
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 225, max: 250)
        } detail: {
            VStack(spacing: 0) {
                if case .updateAvailable(let version, _, let downloadURL, _) = updater.state,
                   appState.selectedTab != .settings {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("CleanMac v\(version) is available.")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button("Install Update") {
                            appState.selectedTab = .settings
                            updater.downloadAndInstallUpdate(version: version, downloadURL: downloadURL)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.green)
                        
                        Button("Details") {
                            appState.selectedTab = .settings
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    
                    Divider()
                }
                
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .onAppear {
            appState.refreshDiskUsage()
            if updater.autoCheckOnLaunch && updater.state == .idle {
                updater.checkForUpdates()
            }
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedTab {
        case .smartScan, .dashboard:
            SmartScanView()
        case .appUninstaller:
            AppUninstallerView()
        case .spaceAnalyzer, .largeOldFiles, .duplicates:
            SpaceAnalyzerView()
        case .settings, .history, .maintenance, .startupItems:
            SettingsView()
        }
    }
}
