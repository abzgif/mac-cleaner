import SwiftUI
import AppKit

/// Visual drill-down disk space analyzer with interactive breadcrumb hierarchy.
public struct SpaceAnalyzerView: View {
    @StateObject private var viewModel = SpaceAnalyzerViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Space Lens & Storage Drilldown")
                        .font(.title2.weight(.bold))
                    Text("Visually explore folders, see what takes up the most disk space, and drill down.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button {
                        chooseCustomDirectory()
                    } label: {
                        Label("Choose Folder...", systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        if let current = viewModel.currentDirectory {
                            viewModel.startScan(at: current.url)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isScanning)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider()
            
            // Breadcrumb navigation bar
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                            Button {
                                viewModel.navigateTo(index: index)
                            } label: {
                                Text(crumb.name)
                                    .font(.system(size: 12, weight: index == viewModel.breadcrumbs.count - 1 ? .bold : .regular))
                                    .foregroundColor(index == viewModel.breadcrumbs.count - 1 ? .primary : .accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            if index < viewModel.breadcrumbs.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if let current = viewModel.currentDirectory {
                    Text("Total: \(current.formattedSize)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            // Notification / alert message
            if let status = viewModel.statusMessage {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(status)
                        .font(.caption)
                    Spacer()
                    Button {
                        viewModel.statusMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                
                Divider()
            }
            
            // Content
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Analyzing folder sizes and distribution...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let current = viewModel.currentDirectory, current.children.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Empty Directory")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("This folder contains no accessible subfolders or files.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let current = viewModel.currentDirectory {
                List {
                    ForEach(current.children) { item in
                        SpaceItemRow(
                            item: item,
                            onDrillDown: { viewModel.drillDown(into: item) },
                            onReveal: { viewModel.revealInFinder(item: item) },
                            onTrash: { viewModel.confirmTrash(item: item) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $viewModel.showTrashAlert,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                viewModel.performTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let item = viewModel.itemPendingTrash {
                Text("Are you sure you want to move '\(item.name)' (\(item.formattedSize)) to the Trash?")
            } else {
                Text("Move selected item to Trash?")
            }
        }
    }
    
    private func chooseCustomDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            viewModel.startScan(at: selectedURL)
        }
    }
}

private struct SpaceItemRow: View {
    let item: SpaceItem
    let onDrillDown: () -> Void
    let onReveal: () -> Void
    let onTrash: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.isDirectory ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 34, height: 34)
                
                Image(systemName: item.iconName)
                    .foregroundColor(item.isDirectory ? .blue : .orange)
                    .font(.system(size: 15))
            }
            
            // Name + Size Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(item.formattedSize)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    
                    Text(String(format: "(%.1f%%)", item.percentage * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                
                // Visual proportion bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(barGradient(for: item.percentage))
                            .frame(width: max(geo.size.width * CGFloat(item.percentage), 4), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    onReveal()
                } label: {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                
                Button {
                    onTrash()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move to Trash")
                
                if item.isDirectory {
                    Button {
                        onDrillDown()
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Drill into folder")
                }
            }
            .padding(.leading, 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if item.isDirectory {
                onDrillDown()
            }
        }
    }
    
    private func barGradient(for pct: Double) -> LinearGradient {
        if pct > 0.4 {
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        } else if pct > 0.15 {
            return LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        }
    }
}
