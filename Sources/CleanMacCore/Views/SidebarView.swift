import SwiftUI

/// Minimal, modern sidebar navigation with integrated disk usage footer.
public struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // App Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("CleanMac")
                        .font(.system(size: 14, weight: .bold))
                    Text("Safe System Cleaner")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            List(selection: $appState.selectedTab) {
                ForEach(NavigationTab.primaryTabs) { tab in
                    NavigationLink(value: tab) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.title)
                                    .font(.system(size: 13, weight: .medium))
                                Text(tab.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .listStyle(.sidebar)
            
            // Minimal Disk Storage Footer
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        Text("Macintosh HD")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(appState.diskUsage.formattedFree) free")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 5)
                            Capsule()
                                .fill(appState.diskUsage.usedRatio > 0.85 ? Color.orange : Color.accentColor)
                                .frame(width: max(geo.size.width * CGFloat(appState.diskUsage.usedRatio), 6), height: 5)
                        }
                    }
                    .frame(height: 5)
                    
                    Text("\(appState.diskUsage.formattedUsed) of \(appState.diskUsage.formattedTotal) used")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}
