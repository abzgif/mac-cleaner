import SwiftUI

final class ConfirmationState: ObservableObject {
    @Published var autoEmptyTrash: Bool = false
}

/// Review and confirmation sheet presented before any cleanup deletion executes.
public struct CleanupConfirmationSheet: View {
    public let selectedItems: [ScannedItem]
    public let totalBytes: Int64
    public let onConfirm: (_ autoEmptyTrash: Bool) -> Void
    public let onCancel: () -> Void
    
    @StateObject private var state = ConfirmationState()
    
    public init(
        selectedItems: [ScannedItem],
        totalBytes: Int64,
        onConfirm: @escaping (_ autoEmptyTrash: Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedItems = selectedItems
        self.totalBytes = totalBytes
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    private var categoryCounts: [ScanCategory: (count: Int, bytes: Int64)] {
        var map: [ScanCategory: (count: Int, bytes: Int64)] = [:]
        for item in selectedItems {
            let current = map[item.category] ?? (count: 0, bytes: 0)
            map[item.category] = (count: current.count + 1, bytes: current.bytes + item.size)
        }
        return map
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                
                Text("Confirm Cleanup")
                    .font(.title2.weight(.bold))
                
                Text("Review the files and space you are about to reclaim.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
            
            // Total Reclaimable Space Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Space to Free")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteFormatter.format(totalBytes))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Selected Files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(selectedItems.count)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            // Category Summary List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(categoryCounts.keys), id: \.self) { cat in
                        if let info = categoryCounts[cat] {
                            HStack {
                                Image(systemName: cat.iconName)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                Text(cat.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(info.count) files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(ByteFormatter.format(info.bytes))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.06))
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
            
            // Safety Assurance Info Box
            HStack(spacing: 10) {
                Image(systemName: "trash")
                    .foregroundColor(.blue)
                Text("Files will be safely moved to macOS Trash. Nothing is permanently destroyed unless configured.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.08))
            )
            
            // Auto Empty Trash Option
            Toggle("Empty macOS Trash automatically after cleaning", isOn: $state.autoEmptyTrash)
                .toggleStyle(.checkbox)
                .font(.caption)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    onConfirm(state.autoEmptyTrash)
                } label: {
                    Label("Move to Trash", systemImage: "trash.fill")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 480)
    }
}
