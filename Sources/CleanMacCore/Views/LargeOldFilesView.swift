import SwiftUI

/// Interface for scanning, sorting, and cleaning large files untouched for extended periods.
public struct LargeOldFilesView: View {
    @StateObject private var viewModel = LargeOldFilesViewModel()
    @StateObject private var settings = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Large & Old Files")
                        .font(.title2.weight(.bold))
                    Text("Locate large forgotten files consuming disk space for manual review.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(viewModel.isScanning ? "Scanning..." : "Scan Files") {
                    viewModel.scan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanning)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider()
            
            HStack(spacing: 16) {
                Menu {
                    Button("50 MB+") { viewModel.minSizeMB = 50; viewModel.scan() }
                    Button("100 MB+") { viewModel.minSizeMB = 100; viewModel.scan() }
                    Button("500 MB+") { viewModel.minSizeMB = 500; viewModel.scan() }
                    Button("1 GB+") { viewModel.minSizeMB = 1000; viewModel.scan() }
                } label: {
                    Label("Min Size: \(viewModel.minSizeMB) MB", systemImage: "line.3.horizontal.decrease.circle")
                }
                .menuStyle(.borderlessButton)
                
                Menu {
                    Button("30+ days") { viewModel.minAgeDays = 30; viewModel.scan() }
                    Button("60+ days") { viewModel.minAgeDays = 60; viewModel.scan() }
                    Button("90+ days") { viewModel.minAgeDays = 90; viewModel.scan() }
                    Button("180+ days") { viewModel.minAgeDays = 180; viewModel.scan() }
                    Button("1+ year") { viewModel.minAgeDays = 365; viewModel.scan() }
                } label: {
                    Label("Older than: \(viewModel.minAgeDays) days", systemImage: "calendar")
                }
                .menuStyle(.borderlessButton)
                
                Menu {
                    ForEach(LargeFileSortOption.allCases) { option in
                        Button(option.rawValue) {
                            viewModel.sortOption = option
                        }
                    }
                } label: {
                    Label("Sort: \(viewModel.sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
                
                if !viewModel.items.isEmpty {
                    Button(viewModel.items.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All") {
                        let all = viewModel.items.allSatisfy { $0.isSelected }
                        viewModel.selectAll(!all)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Searching home folders for files >\(viewModel.minSizeMB) MB older than \(viewModel.minAgeDays) days...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Large & Old Files Discovered")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click 'Scan Files' to search your Downloads, Documents, Movies, and Desktop.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.sortedItems) { item in
                            FileRowView(item: item) {
                                viewModel.toggleItem(item)
                            }
                            Divider()
                        }
                    }
                    .padding(20)
                }
            }
            
            if !viewModel.items.isEmpty {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected for Deletion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.selectedItems.count) files (\(ByteFormatter.format(viewModel.selectedTotalSize)))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.showConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Move Selected to Trash")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.selectedItems.isEmpty || viewModel.isCleaning)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog(
            "Move \(viewModel.selectedItems.count) large files to Trash?",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                viewModel.deleteSelected(userExclusions: Set(settings.userExclusions), autoEmptyTrash: settings.autoEmptyTrash)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("These files will be placed into macOS Trash where they can be restored if needed.")
        }
    }
}
