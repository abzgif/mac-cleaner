import SwiftUI
import AppKit

/// Interface for inspecting and managing login items, background launch agents, and orphaned background daemons.
public struct StartupItemsView: View {
    @StateObject private var viewModel = StartupItemsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Startup & Background Items")
                        .font(.title2.weight(.bold))
                    Text("Manage LaunchAgents and Daemons that start automatically. Clean up orphaned background services.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if viewModel.orphanedCount > 0 {
                        Button {
                            viewModel.selectAllOrphaned()
                        } label: {
                            Label("Select Orphaned (\(viewModel.orphanedCount))", systemImage: "exclamationmark.triangle.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    
                    Button {
                        viewModel.refresh()
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
            
            // Subheader filter & summary bar
            HStack {
                Picker("Filter", selection: $viewModel.filterType) {
                    Text("All Items (\(viewModel.items.count))").tag(StartupItemType?.none)
                    ForEach(StartupItemType.allCases) { type in
                        Text(type.rawValue).tag(StartupItemType?.some(type))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 450)
                
                Spacer()
                
                if !viewModel.selectedItems.isEmpty {
                    Button(role: .destructive) {
                        viewModel.showConfirmation = true
                    } label: {
                        Label("Remove Selected (\(viewModel.selectedItems.count))", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
            
            Divider()
            
            // Notification / status banner
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
            
            // Main List
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Scanning LaunchAgents and LaunchDaemons...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewModel.filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green.opacity(0.8))
                    Text("No Startup Items Found")
                        .font(.headline)
                    Text("Your startup and background services list is clean.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.filteredItems) { item in
                        StartupItemRow(
                            item: item,
                            onToggle: { viewModel.toggleItem(item) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Remove Startup Items?",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(viewModel.selectedItems.count) Item(s) to Trash", role: .destructive) {
                viewModel.removeSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected .plist configurations will be moved safely to Trash. This stops them from launching on startup.")
        }
    }
}

private struct StartupItemRow: View {
    let item: StartupItem
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.isOrphaned ? Color.orange.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: item.isOrphaned ? "exclamationmark.triangle.fill" : "gearshape.2.fill")
                    .foregroundColor(item.isOrphaned ? .orange : .blue)
                    .font(.system(size: 16))
            }
            
            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                    
                    if item.isOrphaned {
                        Text("ORPHANED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                    
                    Text(item.itemType.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                }
                
                Text(item.label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let target = item.programPath {
                    Text(target)
                        .font(.system(size: 10))
                        .foregroundColor(item.isOrphaned ? .orange : .secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action buttons
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            } label: {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal plist in Finder")
        }
        .padding(.vertical, 4)
    }
}
