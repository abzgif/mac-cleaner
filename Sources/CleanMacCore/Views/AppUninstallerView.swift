import SwiftUI
import AppKit

/// Multi-section interface for discovering installed macOS applications, orphaned leftovers, and complete uninstallation.
public struct AppUninstallerView: View {
    @StateObject private var viewModel = AppUninstallerViewModel()
    @StateObject private var settings = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("App Uninstaller & Leftovers")
                        .font(.title2.weight(.bold))
                    Text("Completely remove apps, delete orphaned residual caches, and reclaim storage.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    viewModel.scan()
                } label: {
                    if viewModel.isScanning {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                        }
                    } else {
                        Label("Scan Applications", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanning)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Multiple Section Selector Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AppSection.allCases) { section in
                        SectionPillButton(
                            section: section,
                            count: viewModel.count(for: section),
                            isSelected: viewModel.selectedSection == section,
                            onSelect: {
                                viewModel.selectedSection = section
                                if section != .leftovers && viewModel.selectedAppId == nil {
                                    viewModel.selectedAppId = viewModel.filteredApps.first?.id
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Status banner
            if let status = viewModel.statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
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
                .background(Color.green.opacity(0.1))
                
                Divider()
            }
            
            // Main Content Area
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning applications, system frameworks, and residual support files...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewModel.selectedSection == .leftovers {
                orphanedLeftoversPane
            } else if viewModel.apps.isEmpty {
                emptyAppsView
            } else {
                appsSplitView
            }
        }
        .onAppear {
            if viewModel.apps.isEmpty {
                viewModel.scan()
            }
        }
        .confirmationDialog(
            "Completely uninstall \(viewModel.selectedApp?.name ?? "application")?",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall & Move to Trash", role: .destructive) {
                viewModel.executeUninstall(
                    userExclusions: Set(settings.userExclusions),
                    autoEmptyTrash: settings.autoEmptyTrash
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The application binary and all checked support, preferences, and cache files will be safely moved to macOS Trash.")
        }
    }
    
    // MARK: - Split View for Applications
    
    private var appsSplitView: some View {
        HSplitView {
            // Left App List
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search \(viewModel.selectedSection.rawValue)...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
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
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding(10)
                
                Divider()
                
                if viewModel.filteredApps.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("No applications found in this section.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(selection: $viewModel.selectedAppId) {
                        ForEach(viewModel.filteredApps) { app in
                            AppRowItemView(app: app)
                                .tag(app.id)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 280, maxWidth: 360)
            
            // Right Detail Pane
            if let selected = viewModel.selectedApp {
                AppDetailPaneView(
                    app: selected,
                    viewModel: viewModel,
                    settings: settings
                )
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Select an application from the list to view its files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                    Spacer()
                }
                .frame(minWidth: 420)
            }
        }
    }
    
    // MARK: - Orphaned Leftovers Pane
    
    private var orphanedLeftoversPane: some View {
        VStack(spacing: 0) {
            // Action Subheader
            HStack {
                let selected = viewModel.orphanedLeftovers.filter { $0.isSelected }
                let totalSize = selected.reduce(Int64(0)) { $0 + $1.size }
                
                Text("\(viewModel.orphanedLeftovers.count) Orphaned Residues Found")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Button(viewModel.orphanedLeftovers.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All") {
                    let all = viewModel.orphanedLeftovers.allSatisfy { $0.isSelected }
                    viewModel.selectAllLeftovers(!all)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(role: .destructive) {
                    viewModel.cleanSelectedLeftovers(
                        userExclusions: Set(settings.userExclusions),
                        autoEmptyTrash: settings.autoEmptyTrash
                    )
                } label: {
                    Label("Clean Selected (\(ByteFormatter.format(totalSize)))", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .disabled(selected.isEmpty || viewModel.isUninstalling)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            if viewModel.orphanedLeftovers.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green.opacity(0.8))
                    Text("No Orphaned Leftovers Found")
                        .font(.headline)
                    Text("Your system has no residual support or preferences from uninstalled applications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.filteredLeftovers) { item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { item.isSelected },
                                set: { _ in viewModel.toggleLeftover(item) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "puzzlepiece.extension.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                Text(item.path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Spacer()
                            
                            Text(item.formattedSize)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Button {
                                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private var emptyAppsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Applications Loaded")
                .font(.headline)
            Text("Click 'Scan Applications' to discover all installed apps and their associated files.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Section Pill Button

private struct SectionPillButton: View {
    let section: AppSection
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.iconName)
                    .font(.system(size: 11))
                Text(section.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.12))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Row Item

private struct AppRowItemView: View {
    let app: AppItem
    
    var body: some View {
        HStack(spacing: 10) {
            // Real macOS Application Icon
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                .resizable()
                .frame(width: 26, height: 26)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    if app.isSystemApp {
                        Text("System")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }
                    
                    if app.isUnused && !app.isSystemApp {
                        Text("Unused")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(app.formattedTotalSize)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                    
                    if !app.relatedItems.isEmpty {
                        Text("• \(app.relatedItems.count) leftovers")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - App Detail Pane

private struct AppDetailPaneView: View {
    let app: AppItem
    @ObservedObject var viewModel: AppUninstallerViewModel
    @ObservedObject var settings: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // App Hero Header Card
            HStack(spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                    .resizable()
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .semibold))
                    
                    if let bID = app.bundleIdentifier {
                        Text(bID)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(app.bundleURL.path)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Space")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(app.formattedTotalSize)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            // Multiple File Breakdown Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: Binary Bundle
                    DetailSectionCard(
                        title: "APPLICATION BUNDLE",
                        icon: "macwindow",
                        count: 1,
                        size: app.formattedAppSize
                    ) {
                        HStack {
                            Image(systemName: "app.dashed")
                                .foregroundColor(.accentColor)
                            Text("\(app.name).app")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(app.formattedAppSize)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                    }
                    
                    // Section 2: Application Support
                    if !app.supportItems.isEmpty {
                        DetailSectionCard(
                            title: "APPLICATION SUPPORT & DATA",
                            icon: "folder.fill",
                            count: app.supportItems.count,
                            size: ByteFormatter.format(app.supportItems.reduce(0) { $0 + $1.size })
                        ) {
                            ForEach(app.supportItems) { item in
                                FileRowView(item: item) {
                                    viewModel.toggleRelatedFile(in: app, itemId: item.id)
                                }
                                Divider()
                            }
                        }
                    }
                    
                    // Section 3: Preferences & Plists
                    if !app.preferenceItems.isEmpty {
                        DetailSectionCard(
                            title: "PREFERENCES & CONFIGURATIONS",
                            icon: "slider.horizontal.3",
                            count: app.preferenceItems.count,
                            size: ByteFormatter.format(app.preferenceItems.reduce(0) { $0 + $1.size })
                        ) {
                            ForEach(app.preferenceItems) { item in
                                FileRowView(item: item) {
                                    viewModel.toggleRelatedFile(in: app, itemId: item.id)
                                }
                                Divider()
                            }
                        }
                    }
                    
                    // Section 4: Caches & Logs
                    if !app.cacheItems.isEmpty {
                        DetailSectionCard(
                            title: "CACHES & LOGS",
                            icon: "bolt.horizontal.fill",
                            count: app.cacheItems.count,
                            size: ByteFormatter.format(app.cacheItems.reduce(0) { $0 + $1.size })
                        ) {
                            ForEach(app.cacheItems) { item in
                                FileRowView(item: item) {
                                    viewModel.toggleRelatedFile(in: app, itemId: item.id)
                                }
                                Divider()
                            }
                        }
                    }
                    
                    // Section 5: Containers & Sandbox
                    if !app.containerItems.isEmpty {
                        DetailSectionCard(
                            title: "CONTAINERS & SANDBOX DATA",
                            icon: "shippingbox.fill",
                            count: app.containerItems.count,
                            size: ByteFormatter.format(app.containerItems.reduce(0) { $0 + $1.size })
                        ) {
                            ForEach(app.containerItems) { item in
                                FileRowView(item: item) {
                                    viewModel.toggleRelatedFile(in: app, itemId: item.id)
                                }
                                Divider()
                            }
                        }
                    }
                    
                    // Section 6: Saved State & Others
                    if !app.stateItems.isEmpty || !app.otherItems.isEmpty {
                        let combined = app.stateItems + app.otherItems
                        DetailSectionCard(
                            title: "SAVED STATE & OTHER FILES",
                            icon: "clock.arrow.circlepath",
                            count: combined.count,
                            size: ByteFormatter.format(combined.reduce(0) { $0 + $1.size })
                        ) {
                            ForEach(combined) { item in
                                FileRowView(item: item) {
                                    viewModel.toggleRelatedFile(in: app, itemId: item.id)
                                }
                                Divider()
                            }
                        }
                    }
                }
                .padding(18)
            }
            
            Divider()
            
            // Action Footer
            HStack {
                if app.isSystemApp {
                    Label("Protected macOS system application cannot be removed.", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Moves application and checked leftovers safely to macOS Trash.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    viewModel.promptUninstall()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Uninstall App & Leftovers")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(app.isSystemApp || viewModel.isUninstalling)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 420)
    }
}

// MARK: - Detail Section Card Component

private struct DetailSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    let size: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(count) item\(count == 1 ? "" : "s") • \(size)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            content()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
