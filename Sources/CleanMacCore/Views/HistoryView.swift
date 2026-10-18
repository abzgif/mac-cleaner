import SwiftUI

/// Interface displaying past cleanup audit sessions and providing undo/restore capabilities.
public struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleanup History")
                        .font(.title2.weight(.bold))
                    Text("View past cleanup audit logs and restore items from Trash.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !viewModel.reports.isEmpty {
                    Button("Clear History", role: .destructive) {
                        viewModel.showClearConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider()
            
            // Undo Status Banner
            if let msg = viewModel.undoStatusMessage {
                HStack {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(.blue)
                    Text(msg)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.undoStatusMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
            }
            
            // Metrics Banner
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Space Reclaimed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(viewModel.totalFreedBytes))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                Divider()
                    .frame(height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleanup Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.reports.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            // Report List
            if viewModel.reports.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Cleanup History Yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Completed Smart Scans and manual cleanups will appear here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.reports) { report in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(report.formattedDate)
                                            .font(.system(size: 14, weight: .semibold))
                                        
                                        if report.isUndone {
                                            Text("Restored")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Text("\(report.fileCount) files cleaned")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(report.formattedBytesFreed)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                
                                if !report.isUndone && !report.permanentDeletion {
                                    Button {
                                        viewModel.undo(report: report)
                                    } label: {
                                        Label("Undo / Restore", systemImage: "arrow.uturn.backward")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            // Category Tags
                            HStack(spacing: 6) {
                                ForEach(report.categoriesCleaned, id: \.self) { cat in
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.iconName)
                                            .font(.system(size: 9))
                                        Text(cat.title)
                                            .font(.system(size: 10))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        .confirmationDialog(
            "Clear all cleanup history?",
            isPresented: $viewModel.showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                viewModel.clearAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase past cleanup session logs from CleanMac.")
        }
    }
}
