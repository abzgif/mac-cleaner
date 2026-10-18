import SwiftUI
import AppKit

/// Displays an individual file or directory item with selection toggle, size, and Finder integration.
public struct FileRowView: View {
    public let item: ScannedItem
    public let onToggle: () -> Void
    
    public init(item: ScannedItem, onToggle: @escaping () -> Void) {
        self.item = item
        self.onToggle = onToggle
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            // Icon
            Image(systemName: item.category.iconName)
                .foregroundColor(item.riskWarning != nil ? .orange : .accentColor)
                .frame(width: 20)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    if let warning = item.riskWarning {
                        Text(warning)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    
                    if let error = item.accessError {
                        Text(error)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                
                Text(item.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // File Size
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Quick Look Preview Button
            Button {
                QuickLookHelper.shared.preview(fileURL: item.url)
            } label: {
                Image(systemName: "eye")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quick Look Preview")
            
            // Reveal in Finder Button
            Button {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(item.isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
        )
    }
}
