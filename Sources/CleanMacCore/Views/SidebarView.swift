import SwiftUI

/// Sidebar navigation view rendering primary tabs and disk telemetry glance.
public struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    public var body: some View {
        List(selection: $appState.selectedTab) {
            Section("CLEANER") {
                NavigationLink(value: NavigationTab.dashboard) {
                    Label(NavigationTab.dashboard.title, systemImage: NavigationTab.dashboard.iconName)
                }
                NavigationLink(value: NavigationTab.smartScan) {
                    Label(NavigationTab.smartScan.title, systemImage: NavigationTab.smartScan.iconName)
                }
                NavigationLink(value: NavigationTab.spaceAnalyzer) {
                    Label(NavigationTab.spaceAnalyzer.title, systemImage: NavigationTab.spaceAnalyzer.iconName)
                }
            }
            
            Section("OPTIMIZE") {
                NavigationLink(value: NavigationTab.maintenance) {
                    Label(NavigationTab.maintenance.title, systemImage: NavigationTab.maintenance.iconName)
                }
                NavigationLink(value: NavigationTab.startupItems) {
                    Label(NavigationTab.startupItems.title, systemImage: NavigationTab.startupItems.iconName)
                }
            }
            
            Section("FILES & APPS") {
                NavigationLink(value: NavigationTab.largeOldFiles) {
                    Label(NavigationTab.largeOldFiles.title, systemImage: NavigationTab.largeOldFiles.iconName)
                }
                NavigationLink(value: NavigationTab.duplicates) {
                    Label(NavigationTab.duplicates.title, systemImage: NavigationTab.duplicates.iconName)
                }
                NavigationLink(value: NavigationTab.appUninstaller) {
                    Label(NavigationTab.appUninstaller.title, systemImage: NavigationTab.appUninstaller.iconName)
                }
            }
            
            Section("MANAGE") {
                NavigationLink(value: NavigationTab.history) {
                    Label(NavigationTab.history.title, systemImage: NavigationTab.history.iconName)
                }
                NavigationLink(value: NavigationTab.settings) {
                    Label(NavigationTab.settings.title, systemImage: NavigationTab.settings.iconName)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 12))
                        Text("Macintosh HD")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text("\(appState.diskUsage.formattedFree) Free")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                    }
                    
                    // Mini storage bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: max(geo.size.width * CGFloat(appState.diskUsage.usedRatio), 4), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }
}
