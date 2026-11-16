import SwiftUI
import AppKit

/// Minimal, unified Settings & Safety view managing in-app updates, exclusions, cleanup behavior, built-in IDE/app protections, and cleanup history.
public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var historyVM = HistoryViewModel()
    @StateObject private var updater = AppUpdaterViewModel.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                softwareUpdateSection
                safetyProtectionSection
                cleanupPreferencesSection
                excludedFoldersSection
                historySection
            }
            .padding(28)
        }
        .onAppear {
            historyVM.refresh()
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings & Protection")
                .font(.system(size: 22, weight: .bold))
            Text("Check for app updates, manage safety exclusions, cleanup behavior, and session history.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var softwareUpdateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SOFTWARE UPDATE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            SoftwareUpdateCard(updater: updater)
        }
    }
    
    private var safetyProtectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVE SAFETY PROTECTIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Application Data, IDEs & Download Managers Protected")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Smart Clean automatically preserves ~/Library/Application Support, ~/Library/Preferences, .app bundle contents, JDownloader 2, and Android Studio IDE settings while letting you clean SDKs on demand.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var cleanupPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CLEANUP PREFERENCES")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 1) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safe Trash Protection for User Files & Apps")
                            .font(.system(size: 13, weight: .medium))
                        Text("Uninstalled apps, installers, and personal files are placed in macOS Trash so you can restore them anytime.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Always On")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                }
                .padding(14)
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatically Empty Trash After Clean")
                            .font(.system(size: 13, weight: .medium))
                        Text("Empty the macOS Trash bin immediately after moving selected items.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.autoEmptyTrash)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
    private var excludedFoldersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXCLUDED FOLDERS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("Folders listed here will never be scanned or modified.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    if let chosenURL = PermissionHelper.promptForDirectoryAccess(
                        message: "Select a folder to exclude from CleanMac scans.",
                        prompt: "Exclude Folder"
                    ) {
                        viewModel.addExclusion(chosenURL.path)
                    }
                } label: {
                    Label("Add Folder...", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if viewModel.userExclusions.isEmpty {
                Text("No custom folders added. Standard system, IDE, and application protections are active.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    )
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(viewModel.userExclusions.enumerated()), id: \.offset) { index, path in
                        ExcludedPathRow(path: path) {
                            viewModel.removeExclusion(at: index)
                        }
                    }
                }
            }
        }
    }
    
    private var historySection: some View {
        let recentReports = Array(historyVM.reports.prefix(8))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT CLEANUP HISTORY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Total Freed: \(ByteFormatter.format(historyVM.totalFreedBytes))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            if let msg = historyVM.undoStatusMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
            }
            
            if recentReports.isEmpty {
                Text("No cleanup sessions recorded yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(recentReports) { report in
                        HistoryReportRow(report: report) {
                            historyVM.undo(report: report)
                        }
                    }
                }
            }
        }
    }
}

private struct SoftwareUpdateCard: View {
    @ObservedObject var updater: AppUpdaterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("CleanMac v\(updater.currentVersion)")
                            .font(.system(size: 14, weight: .bold))
                        Text("Build \(updater.currentBuild)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                    
                    statusSubtitleView
                }
                
                Spacer()
                
                actionButtonsView
            }
            
            if case .updateAvailable(let version, let notes, _, let releasePageURL) = updater.state {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("What's New in v\(version)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Link("View on GitHub", destination: releasePageURL)
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2)
            }
            
            Divider()
            
            HStack {
                Text("Automatically check for updates on launch")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $updater.autoCheckOnLaunch)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusSubtitleView: some View {
        switch updater.state {
        case .idle:
            if let last = updater.lastCheckedDate {
                Text("Last checked \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("Check GitHub Releases for the latest version of CleanMac.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking GitHub for updates...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        case .upToDate(let ver):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("CleanMac v\(ver) is up to date.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
        case .updateAvailable(let version, _, _, _):
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 11))
                Text("New version v\(version) is available to install!")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        case .downloading(let version):
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading CleanMac v\(version)...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        case .installing(let version):
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing v\(version) and restarting CleanMac...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.orange)
                .lineLimit(2)
        }
    }
    
    @ViewBuilder
    private var actionButtonsView: some View {
        switch updater.state {
        case .updateAvailable(let version, _, let downloadURL, _):
            HStack(spacing: 8) {
                Button("Check Again") {
                    updater.checkForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button {
                    updater.downloadAndInstallUpdate(version: version, downloadURL: downloadURL)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Install v\(version)")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.green)
            }
        case .checking, .downloading, .installing:
            Button("Checking...") {}
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(true)
        default:
            Button {
                updater.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
}

private struct ExcludedPathRow: View {
    let path: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.accentColor)
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }
}

private struct HistoryReportRow: View {
    let report: CleanupReport
    let onUndo: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(report.formattedBytesFreed) freed • \(report.fileCount) items")
                    .font(.system(size: 12, weight: .semibold))
                Text(report.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !report.isUndone && !report.permanentDeletion {
                Button("Restore from Trash", action: onUndo)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else if report.isUndone {
                Text("Restored")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
    }
}
