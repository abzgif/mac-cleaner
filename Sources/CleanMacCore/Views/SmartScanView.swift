import SwiftUI

/// Main Smart Scan interface displaying live multi-category progress, collapsible review lists, and safe deletion confirmation.
public struct SmartScanView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SmartScanViewModel()
    @StateObject private var settings = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Smart Scan")
                        .font(.title2.weight(.bold))
                    Text("Intelligently locate harmless caches, stale logs, and developer residue.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.isScanning {
                    Button("Cancel Scan", role: .destructive) {
                        viewModel.cancelScan()
                    }
                    .buttonStyle(.bordered)
                } else if viewModel.hasCompletedScan {
                    Button("Rescan") {
                        viewModel.startScan()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider()
            
            // Content Body
            if viewModel.isScanning {
                scanningProgressView
            } else if viewModel.hasCompletedScan {
                resultsReviewView
            } else {
                initialScanView
            }
            
            // Bottom Action Bar (when results exist)
            if viewModel.hasCompletedScan && !viewModel.isScanning {
                bottomBar
            }
        }
        .sheet(isPresented: $viewModel.showConfirmationSheet) {
            CleanupConfirmationSheet(
                selectedItems: viewModel.scanResult.selectedItems,
                totalBytes: viewModel.scanResult.selectedSize,
                onConfirm: { autoEmpty in
                    viewModel.executeCleanup(
                        userExclusions: Set(settings.userExclusions),
                        autoEmptyTrash: autoEmpty || settings.autoEmptyTrash,
                        permanentDelete: settings.allowPermanentDeletion
                    ) {
                        appState.refreshDiskUsage()
                    }
                },
                onCancel: {
                    viewModel.showConfirmationSheet = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showResultSheet) {
            cleanupCompletedSheet
        }
    }
    
    // MARK: - Subviews
    
    private var initialScanView: some View {
        ScrollView {
            VStack(spacing: 16) {
                PermissionBannerView()
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    ForEach(ScanCategory.allCases.filter { $0.isDefaultSmartScan }) { category in
                        CategoryCardView(
                            category: category,
                            itemCount: 0,
                            totalBytes: 0,
                            isSelected: viewModel.selectedCategories.contains(category),
                            onToggle: {
                                if viewModel.selectedCategories.contains(category) {
                                    viewModel.selectedCategories.remove(category)
                                } else {
                                    viewModel.selectedCategories.insert(category)
                                }
                            }
                        )
                    }
                }
                
                Button {
                    viewModel.startScan()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Scan Now")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 180, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 12)
            }
            .padding(24)
        }
    }
    
    private var scanningProgressView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.4)
            
            VStack(spacing: 8) {
                Text(viewModel.progress?.statusMessage ?? "Scanning filesystem...")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 450)
                
                HStack(spacing: 16) {
                    Text("\(viewModel.progress?.itemsFoundCount ?? 0) items discovered")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(ByteFormatter.format(viewModel.progress?.bytesFound ?? 0))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
            }
            
            ProgressView(value: viewModel.progress?.progressFraction ?? 0.0)
                .frame(width: 320)
                .padding(.top, 4)
            
            Spacer()
        }
    }
    
    private var resultsReviewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !viewModel.scanResult.inaccessiblePaths.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("\(viewModel.scanResult.inaccessiblePaths.count) items could not be accessed due to macOS privacy restrictions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
                }
                
                ForEach(Array(viewModel.selectedCategories), id: \.self) { category in
                    let items = viewModel.scanResult.items(for: category)
                    let categorySize = viewModel.scanResult.size(for: category)
                    let isExpanded = viewModel.expandedCategories.contains(category)
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Button {
                                viewModel.toggleExpansion(for: category)
                            } label: {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .frame(width: 16)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Image(systemName: category.iconName)
                                .foregroundColor(.accentColor)
                            
                            Text(category.title)
                                .font(.system(size: 14, weight: .semibold))
                            
                            Spacer()
                            
                            Text(ByteFormatter.format(categorySize))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            
                            Button(items.allSatisfy { $0.isSelected } ? "Deselect" : "Select All") {
                                let allSelected = items.allSatisfy { $0.isSelected }
                                viewModel.toggleAllItems(in: category, select: !allSelected)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                        
                        if isExpanded {
                            VStack(spacing: 1) {
                                if items.isEmpty {
                                    Text("No junk files found in this category.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(12)
                                } else {
                                    ForEach(items) { item in
                                        FileRowView(item: item) {
                                            viewModel.toggleItemSelection(item)
                                        }
                                        Divider()
                                    }
                                }
                            }
                            .padding(.leading, 12)
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
            .padding(24)
        }
    }
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected: \(viewModel.scanResult.selectedItems.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.scanResult.formattedSelectedSize)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button {
                    viewModel.promptReview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Review & Clean")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
                .disabled(viewModel.scanResult.selectedItems.isEmpty || viewModel.isCleaning)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
    }
    
    private var cleanupCompletedSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Cleanup Complete!")
                .font(.title2.weight(.bold))
            
            if let result = viewModel.lastCleanupResult {
                VStack(spacing: 6) {
                    Text(ByteFormatter.format(result.report.bytesFreed))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("\(result.report.fileCount) files moved to macOS Trash safely")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !result.skippedViolations.isEmpty {
                    Text("\(result.skippedViolations.count) items were protected by safety policy and skipped.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Button("Done") {
                viewModel.showResultSheet = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 420)
    }
}
