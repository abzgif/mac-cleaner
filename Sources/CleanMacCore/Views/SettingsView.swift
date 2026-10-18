import SwiftUI
import AppKit

/// Application settings view managing Smart Scan categories, exclusions, age thresholds, and safety rules.
public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings & Preferences")
                        .font(.title2.weight(.bold))
                    Text("Configure scanning behaviors, safety limits, and custom excluded folders.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section 1: Smart Scan Categories
                VStack(alignment: .leading, spacing: 12) {
                    Text("SMART SCAN INCLUDED CATEGORIES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(ScanCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(category.title)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(category.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { viewModel.smartScanCategories.contains(category) },
                                    set: { _ in viewModel.toggleCategory(category) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
                        }
                    }
                }
                
                Divider()
                
                // Section 2: File Age Thresholds
                VStack(alignment: .leading, spacing: 12) {
                    Text("AUTOMATIC SCAN THRESHOLDS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Downloads & Old Files Age Cutoff")
                                .font(.system(size: 13, weight: .medium))
                            Text("Files not modified in this many days are marked as candidates.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $viewModel.oldFilesAgeThresholdDays) {
                            Text("14 Days").tag(14)
                            Text("30 Days").tag(30)
                            Text("60 Days").tag(60)
                            Text("90 Days").tag(90)
                            Text("180 Days").tag(180)
                        }
                        .frame(width: 140)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
                }
                
                Divider()
                
                // Section 3: Safety & Automation
                VStack(alignment: .leading, spacing: 12) {
                    Text("DELETION BEHAVIOR & AUTOMATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Toggle(isOn: $viewModel.autoEmptyTrash) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Empty Trash After Clean")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Automatically empty the macOS Trash bin upon completing a cleanup session.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
                        
                        Toggle(isOn: $viewModel.launchAtLogin) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch CleanMac at Login")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Run silently in the background and menu bar to monitor storage health.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
                    }
                }
                
                Divider()
                
                // Section 4: User Custom Excluded Paths (Denylist Additions)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("USER-MANAGED EXCLUDED PATHS (DENYLIST)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("Files and directories in this list will NEVER be scanned or cleaned.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            if let chosenURL = PermissionHelper.promptForDirectoryAccess(
                                message: "Select a folder to permanently exclude from CleanMac scans.",
                                prompt: "Exclude Folder"
                            ) {
                                viewModel.addExclusion(chosenURL.path)
                            }
                        } label: {
                            Label("Add Folder...", systemImage: "plus.circle")
                        }
                    }
                    
                    if viewModel.userExclusions.isEmpty {
                        Text("No custom exclusions added. All standard safety denylists (/System, /bin, user essentials) remain active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.userExclusions.indices, id: \.self) { index in
                                HStack {
                                    Image(systemName: "folder.badge.minus")
                                        .foregroundColor(.orange)
                                    Text(viewModel.userExclusions[index])
                                        .font(.system(size: 12, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button {
                                        viewModel.removeExclusion(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
