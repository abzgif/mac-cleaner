import SwiftUI
import AppKit

final class PermissionBannerState: ObservableObject {
    @Published var hasFDA: Bool = PermissionHelper.hasFullDiskAccess
    @Published var isDismissed: Bool = false
    
    func refresh() {
        hasFDA = PermissionHelper.hasFullDiskAccess
    }
}

/// Banner prompting the user to grant Full Disk Access for scanning protected system caches and logs.
public struct PermissionBannerView: View {
    @StateObject private var state = PermissionBannerState()
    
    public init() {}
    
    public var body: some View {
        if !state.hasFDA && !state.isDismissed {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Full Disk Access Recommended")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Enable CleanMac in System Settings to scan protected system caches and logs.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Button("Open Settings") {
                            PermissionHelper.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button {
                            relaunchApp()
                        } label: {
                            Label("Restart App", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Restart CleanMac after enabling Full Disk Access in System Settings")
                        
                        Button {
                            state.isDismissed = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Dismiss warning")
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("Already granted? Ensure the switch is ON, then click Restart App.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Check Again") {
                        state.refresh()
                    }
                    .buttonStyle(.link)
                    .font(.caption2)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                state.refresh()
            }
        }
    }
    
    private func relaunchApp() {
        let appURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", appURL.path]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
}
