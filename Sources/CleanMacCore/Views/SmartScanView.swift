import SwiftUI

/// Modern, minimal Smart Clean interface combining live storage overview, category selection, and safe cleanup.
public struct SmartScanView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SmartScanViewModel()
    @StateObject private var settings = SettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Minimal Top Header & Storage Overview
            topStorageHeader
            
            Divider()
            
            // Main Content
            if viewModel.isScanning {
                scanningProgressView
            } else if viewModel.hasCompletedScan {
                resultsReviewView
            } else {
                categorySelectionView
            }
            
            // Bottom Action Bar
            bottomActionBar
        }
        .sheet(isPresented: $viewModel.showConfirmationSheet) {
            CleanupConfirmationSheet(
                selectedItems: viewModel.scanResult.selectedItems,
                totalBytes: viewModel.scanResult.selectedSize,
                onConfirm: { autoEmpty in
                    viewModel.executeCleanup(
                        userExclusions: Set(settings.userExclusions),
                        autoEmptyTrash: autoEmpty || settings.autoEmptyTrash
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
    
    // MARK: - Top Storage Header
    
    private var topStorageHeader: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Smart Clean")
                            .font(.system(size: 22, weight: .bold))
                        
                        // Safety Shield Pill
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 10))
                            Text("App Data & IDEs Protected")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                    }
                    
                    Text("Safely remove temporary caches, logs, and trash without touching app settings or SDKs.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Compact Storage Card
                HStack(spacing: 14) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(appState.diskUsage.formattedFree) Available")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("\(appState.diskUsage.formattedUsed) used of \(appState.diskUsage.formattedTotal)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                            .frame(width: 38, height: 38)
                        Circle()
                            .trim(from: 0, to: CGFloat(appState.diskUsage.usedRatio))
                            .stroke(
                                appState.diskUsage.usedRatio > 0.85 ? Color.orange : Color.accentColor,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 38, height: 38)
                        Text("\(Int(appState.diskUsage.usedRatio * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }
    
    // MARK: - Category Selection View
    
    private var categorySelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PermissionBannerView()
                
                Text("SCAN CATEGORIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 10) {
                    ForEach(ScanCategory.smartCleanCategories) { category in
                        let isSelected = viewModel.selectedCategories.contains(category)
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                                    .frame(width: 38, height: 38)
                                Image(systemName: category.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(category.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    
                                    if !category.isDefaultSmartScan {
                                        Text("Optional")
                                            .font(.system(size: 9, weight: .medium))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(category.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { isSelected },
                                set: { checked in
                                    if checked {
                                        viewModel.selectedCategories.insert(category)
                                    } else {
                                        viewModel.selectedCategories.remove(category)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(28)
        }
    }
    
    // MARK: - Scanning Progress View
    
    private var scanningProgressView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.3)
            
            VStack(spacing: 6) {
                Text(viewModel.progress?.statusMessage ?? "Scanning safe cache locations...")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
                
                HStack(spacing: 12) {
                    Text("\(viewModel.progress?.itemsFoundCount ?? 0) items found")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    Text(ByteFormatter.format(viewModel.progress?.bytesFound ?? 0))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }
            
            ProgressView(value: viewModel.progress?.progressFraction ?? 0.1)
                .frame(width: 280)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results Review View
    
    private var resultsReviewView: some View {
        ScrollView {
            VStack(spacing: 12) {
                let orderedCategories = ScanCategory.smartCleanCategories.filter { viewModel.selectedCategories.contains($0) }
                
                if viewModel.scanResult.allItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                        Text("Your Mac is Clean!")
                            .font(.system(size: 18, weight: .bold))
                        Text("No unneeded cache or log files were found in the selected categories.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 60)
                } else {
                    ForEach(orderedCategories) { category in
                        let items = viewModel.scanResult.items(for: category)
                        let categorySize = viewModel.scanResult.size(for: category)
                        let selectedCategorySize = viewModel.scanResult.selectedSize(for: category)
                        let isExpanded = viewModel.expandedCategories.contains(category)
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Button {
                                    viewModel.toggleExpansion(for: category)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .frame(width: 14)
                                        
                                        Image(systemName: category.iconName)
                                            .foregroundColor(.accentColor)
                                            .frame(width: 20)
                                        
                                        Text(category.title)
                                            .font(.system(size: 13, weight: .semibold))
                                        
                                        Text("\(items.count)")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                if !items.isEmpty {
                                    Button(items.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All") {
                                        let allSelected = items.allSatisfy { $0.isSelected }
                                        viewModel.toggleAllItems(in: category, select: !allSelected)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.accentColor)
                                }
                                
                                Text(ByteFormatter.format(selectedCategorySize > 0 ? selectedCategorySize : categorySize))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(selectedCategorySize > 0 ? .primary : .secondary)
                                    .frame(minWidth: 75, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                            
                            if isExpanded {
                                Divider()
                                if items.isEmpty {
                                    HStack {
                                        Text("No unneeded files found in this category.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                } else {
                                    LazyVStack(spacing: 0) {
                                        ForEach(items) { item in
                                            FileRowView(item: item) {
                                                viewModel.toggleItemSelection(item)
                                            }
                                            Divider()
                                                .padding(.leading, 40)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(28)
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                if viewModel.hasCompletedScan && !viewModel.isScanning {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.scanResult.selectedItems.count) items selected to clean")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(viewModel.scanResult.formattedSelectedSize)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button("Categories") {
                        viewModel.resetScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Rescan") {
                        viewModel.startScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        viewModel.promptReview()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Clean Now")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.green)
                    .disabled(viewModel.scanResult.selectedItems.isEmpty || viewModel.isCleaning)
                } else if viewModel.isScanning {
                    Text("Scanning selected locations...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Cancel Scan") {
                        viewModel.cancelScan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Text("\(viewModel.selectedCategories.count) categories selected")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        viewModel.startScan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Start Smart Scan")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.selectedCategories.isEmpty)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Cleanup Completed Sheet
    
    private var cleanupCompletedSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundColor(.green)
            
            Text("Cleanup Complete")
                .font(.system(size: 20, weight: .bold))
            
            if let result = viewModel.lastCleanupResult {
                VStack(spacing: 4) {
                    Text(ByteFormatter.format(result.report.bytesFreed))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("\(result.report.fileCount) items safely moved to Trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                if !result.skippedViolations.isEmpty {
                    Text("\(result.skippedViolations.count) protected items were preserved.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Done") {
                viewModel.showResultSheet = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 380)
    }
}
