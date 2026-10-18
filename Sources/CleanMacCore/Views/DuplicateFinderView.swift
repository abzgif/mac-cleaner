import SwiftUI

/// Interface for identifying, comparing, and removing duplicate files with SHA-256 validation.
public struct DuplicateFinderView: View {
    @StateObject private var viewModel = DuplicateFinderViewModel()
    @StateObject private var settings = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Duplicate Files")
                        .font(.title2.weight(.bold))
                    Text("Scan for byte-for-byte identical files verified by SHA-256 cryptographic hashing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(viewModel.isScanning ? "Scanning..." : "Find Duplicates") {
                    viewModel.scan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanning)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider()
            
            if !viewModel.duplicateGroups.isEmpty {
                HStack(spacing: 12) {
                    Text("Auto-Selection:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(DuplicateSelectionStrategy.allCases) { strategy in
                        Button(strategy.rawValue) {
                            viewModel.applyStrategy(strategy)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.duplicateGroups.count) Duplicate Groups")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                
                Divider()
            }
            
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text(viewModel.statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewModel.duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Duplicates Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Click 'Find Duplicates' to scan your Downloads and Documents.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.duplicateGroups) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Image(systemName: "doc.on.doc.fill")
                                        .foregroundColor(.accentColor)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(group.files.count) Copies (\(group.formattedFileSize) each)")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("SHA-256: \(group.hash.prefix(16))...")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Reclaim: \(group.formattedReclaimableSize)")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.green)
                                }
                                .padding(12)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                                
                                Divider()
                                
                                ForEach(group.files) { file in
                                    FileRowView(item: file) {
                                        viewModel.toggleItem(file)
                                    }
                                    Divider()
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.3)))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
            }
            
            if !viewModel.duplicateGroups.isEmpty {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Duplicates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.selectedCount) files (\(ByteFormatter.format(viewModel.selectedBytes)))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.showConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Move Duplicates to Trash")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.selectedCount == 0 || viewModel.isCleaning)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog(
            "Move \(viewModel.selectedCount) duplicate files to Trash?",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                viewModel.deleteSelected(userExclusions: Set(settings.userExclusions), autoEmptyTrash: settings.autoEmptyTrash)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected duplicate copies will be safely sent to Trash, leaving one original copy intact.")
        }
    }
}
