import SwiftUI
import AppKit

/// Clean, filter-free interface for selecting single or multiple macOS applications to uninstall and clean their residual files.
public struct AppUninstallerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AppUninstallerViewModel()
    @StateObject private var settings = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header (Filter removed for a clean, uncluttered layout)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Applications")
                        .font(.system(size: 22, weight: .bold))
                    Text("Check one or multiple applications to uninstall them along with their support and cache files.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    viewModel.scan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isScanning)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            
            Divider()
            
            // Status Banner
            if let status = viewModel.statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(status)
                        .font(.system(size: 12))
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
                .background(Color.green.opacity(0.1))
                
                Divider()
            }
            
            // Main Content
            if viewModel.isScanning {
                VStack(spacing: 14) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning installed applications...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.userApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Applications Loaded")
                        .font(.headline)
                    Button("Scan Applications") {
                        viewModel.scan()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    leftAppListPane
                    rightDetailPane
                }
            }
        }
        .onAppear {
            if viewModel.apps.isEmpty {
                viewModel.scan()
            }
        }
        .confirmationDialog(
            uninstallDialogTitle,
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button(uninstallConfirmButtonTitle, role: .destructive) {
                viewModel.executeUninstall(
                    userExclusions: Set(settings.userExclusions),
                    autoEmptyTrash: settings.autoEmptyTrash
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected application bundles and all checked support, cache, and preference files (\(ByteFormatter.format(viewModel.totalUninstallSize))) will be moved safely to macOS Trash.")
        }
    }
    
    private var uninstallDialogTitle: String {
        let targets = viewModel.appsToUninstall
        if targets.count == 1, let first = targets.first {
            return "Uninstall \(first.name)?"
        }
        return "Uninstall \(targets.count) Selected Applications?"
    }
    
    private var uninstallConfirmButtonTitle: String {
        let targets = viewModel.appsToUninstall
        if targets.count <= 1 {
            return "Uninstall & Clean Files"
        }
        return "Uninstall \(targets.count) Apps & Clean Files"
    }
    
    // MARK: - Left Column: Multi-Select Application List
    
    private var leftAppListPane: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search applications...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Multi-Select Summary & Select All Bar
            HStack {
                if !viewModel.checkedApps.isEmpty {
                    Text("\(viewModel.checkedApps.count) selected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                } else {
                    Text("\(viewModel.filteredApps.count) applications")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !viewModel.filteredApps.isEmpty {
                    let allSelected = viewModel.filteredApps.allSatisfy { $0.isSelected }
                    Button(allSelected ? "Deselect All" : "Select All") {
                        viewModel.selectAllFiltered(!allSelected)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            
            Divider()
            
            if viewModel.filteredApps.isEmpty {
                VStack {
                    Spacer()
                    Text("No matching applications")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $viewModel.selectedAppId) {
                    ForEach(viewModel.filteredApps) { app in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { app.isSelected },
                                set: { _ in viewModel.toggleAppSelection(app) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text("\(app.relatedItems.count + 1) items")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(app.formattedTotalSize)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(app.isSelected ? .accentColor : .secondary)
                        }
                        .padding(.vertical, 3)
                        .tag(app.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 270, idealWidth: 300, maxWidth: 350)
    }
    
    // MARK: - Right Column: Selected App(s) Details & Batch Action Footer
    
    private var rightDetailPane: some View {
        VStack(spacing: 0) {
            if let selected = viewModel.selectedApp {
                AppDetailInspectorView(app: selected, viewModel: viewModel)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "macwindow")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Select an application to inspect its files")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 440)
    }
}

private struct AppDetailInspectorView: View {
    let app: AppItem
    @ObservedObject var viewModel: AppUninstallerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Multi-App Batch Banner (shown when >1 apps are checked)
            if viewModel.checkedApps.count > 1 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("\(viewModel.checkedApps.count) applications checked for batch uninstall")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("Clear Selection") {
                        viewModel.selectAllFiltered(false)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                
                Divider()
            }
            
            // Focused App Summary Header
            HStack(spacing: 16) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable()
                    .frame(width: 52, height: 52)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 17, weight: .bold))
                    if let bID = app.bundleIdentifier {
                        Text(bID)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Text(app.bundleURL.path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("App Total")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(app.formattedTotalSize)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            // Scrollable File Breakdown
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // When multiple apps are checked, show a compact batch summary list first
                    if viewModel.checkedApps.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SELECTED APPLICATIONS (\(viewModel.checkedApps.count))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 6) {
                                ForEach(viewModel.checkedApps) { checkedApp in
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: checkedApp.bundleURL.path))
                                            .resizable()
                                            .frame(width: 22, height: 22)
                                        Text(checkedApp.name)
                                            .font(.system(size: 12, weight: .medium))
                                        Text("(\(checkedApp.relatedItems.filter { $0.isSelected }.count) support files)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(checkedApp.formattedTotalSize)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        Button {
                                            viewModel.toggleAppSelection(checkedApp)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                    )
                                }
                            }
                        }
                    }
                    
                    // Main App Bundle Row
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APPLICATION BUNDLE — \(app.name.uppercased())")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.square.fill")
                                .foregroundColor(.accentColor)
                            Image(systemName: "app.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.bundleURL.lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))
                                Text(app.bundleURL.path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(app.formattedAppSize)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        )
                    }
                    
                    if !app.relatedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ASSOCIATED FILES FOR \(app.name.uppercased()) (\(app.relatedItems.count))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 0) {
                                ForEach(app.relatedItems) { item in
                                    FileRowView(item: item) {
                                        viewModel.toggleRelatedFile(in: app, itemId: item.id)
                                    }
                                    Divider()
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                            )
                        }
                    } else {
                        Text("No additional support or preference files detected for \(app.name).")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Bottom Action Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let count = viewModel.appsToUninstall.count
                    Text("\(count) app\(count == 1 ? "" : "s") (\(viewModel.totalUninstallItemCount) items) selected")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(viewModel.totalUninstallSize))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Button {
                    viewModel.promptUninstall()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        if viewModel.appsToUninstall.count > 1 {
                            Text("Uninstall \(viewModel.appsToUninstall.count) Apps & Clean")
                                .fontWeight(.semibold)
                        } else {
                            Text("Uninstall & Clean")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .disabled(viewModel.appsToUninstall.isEmpty || viewModel.isUninstalling)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
    }
}
