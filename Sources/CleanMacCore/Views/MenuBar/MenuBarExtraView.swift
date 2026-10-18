import SwiftUI
import AppKit

final class MenuBarState: ObservableObject {
    @Published var isCleaning: Bool = false
    @Published var statusMessage: String?
}

/// Menu bar popup view offering quick storage glance and one-click cleanup.
public struct MenuBarExtraView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var state = MenuBarState()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("CleanMac Glance")
                    .font(.headline)
                Spacer()
                Text(appState.diskUsage.formattedFree + " Free")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
            }
            
            // Usage Progress
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: appState.diskUsage.usedRatio)
                    .tint(appState.diskUsage.usedRatio > 0.85 ? .orange : .blue)
                HStack {
                    Text("\(Int(appState.diskUsage.usedRatio * 100))% of \(appState.diskUsage.formattedTotal) used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            if let msg = state.statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            // Actions
            HStack {
                Button {
                    quickClean()
                } label: {
                    Label(state.isCleaning ? "Cleaning..." : "Quick Clean", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(state.isCleaning)
                
                Spacer()
                
                Button("Open CleanMac") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    private func quickClean() {
        guard !state.isCleaning else { return }
        state.isCleaning = true
        state.statusMessage = "Scanning caches and logs..."
        
        Task { @MainActor in
            let scanEngine = appState.scanEngine
            let cleanupEngine = appState.cleanupEngine
            
            let result = await scanEngine.scan(categories: [.systemCaches, .userLogs, .trash])
            let selected = result.allItems
            
            if selected.isEmpty {
                state.statusMessage = "System is already clean!"
            } else {
                state.statusMessage = "Cleaning \(selected.count) items..."
                let cleanResult = try? await cleanupEngine.clean(items: selected, autoEmptyTrash: false)
                let freed = cleanResult?.report.bytesFreed ?? 0
                state.statusMessage = "Reclaimed \(ByteFormatter.format(freed))!"
                appState.refreshDiskUsage()
            }
            state.isCleaning = false
        }
    }
}
