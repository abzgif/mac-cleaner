import SwiftUI
import AppKit

/// Unified Storage Explorer combining visual folder drilldown, large file discovery, and duplicate finder in one minimal screen.
public struct SpaceAnalyzerView: View {
    @StateObject private var viewModel = SpaceAnalyzerViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified Top Header with Segmented Switcher
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Explorer")
                        .font(.system(size: 22, weight: .bold))
                    Text("Inspect folder sizes, locate large forgotten files, or find duplicate copies.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $viewModel.explorerMode) {
                    ForEach(StorageExplorerMode.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            
            Divider()
            
            // Subview Switcher
            switch viewModel.explorerMode {
            case .folders:
                folderDrilldownView
            case .largeFiles:
                LargeOldFilesView()
            case .duplicates:
                DuplicateFinderView()
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
    
    // MARK: - Folder Drilldown View
    
    private var folderDrilldownView: some View {
        VStack(spacing: 0) {
            // Breadcrumb & Folder Action Bar
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                            Button {
                                viewModel.navigateTo(index: index)
                            } label: {
                                Text(crumb.name)
                                    .font(.system(size: 12, weight: index == viewModel.breadcrumbs.count - 1 ? .semibold : .regular))
                                    .foregroundColor(index == viewModel.breadcrumbs.count - 1 ? .primary : .accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            if index < viewModel.breadcrumbs.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if let current = viewModel.currentDirectory {
                    Text(current.formattedSize)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Button("Choose Folder...") {
                    chooseCustomDirectory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    if let current = viewModel.currentDirectory {
                        viewModel.startScan(at: current.url)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isScanning)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
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
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                
                Divider()
            }
            
            if viewModel.isScanning {
                VStack(spacing: 14) {
                    Spacer()
                    ProgressView()
                    Text("Calculating folder sizes...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let current = viewModel.currentDirectory, current.children.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Folder is Empty")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    }
    
    private func chooseCustomDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Analyze Folder"
        
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
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.isDirectory ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: item.iconName)
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(item.formattedSize)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    
                    Text(String(format: "%.0f%%", item.percentage * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(item.percentage > 0.4 ? Color.orange : Color.accentColor)
                            .frame(width: max(geo.size.width * CGFloat(item.percentage), 4), height: 5)
                    }
                }
                .frame(height: 5)
            }
            
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open Folder")
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
}
