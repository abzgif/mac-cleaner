import SwiftUI

/// Card view representing a scan category summary with count, size, and toggle switch.
public struct CategoryCardView: View {
    public let category: ScanCategory
    public let itemCount: Int
    public let totalBytes: Int64
    public let isSelected: Bool
    public let onToggle: () -> Void
    
    public init(
        category: ScanCategory,
        itemCount: Int,
        totalBytes: Int64,
        isSelected: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.category = category
        self.itemCount = itemCount
        self.totalBytes = totalBytes
        self.isSelected = isSelected
        self.onToggle = onToggle
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 36, height: 36)
                
                Image(systemName: category.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            
            // Text Information
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.title)
                        .font(.system(size: 13, weight: .semibold))
                    
                    if category.isHighRisk {
                        Text("High Risk")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }
                
                Text(category.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Size and Toggle
            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormatter.format(totalBytes))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                
                Text("\(itemCount) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
