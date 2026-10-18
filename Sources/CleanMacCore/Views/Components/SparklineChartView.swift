import SwiftUI

/// Renders a sparkline vector trend for historical space-freed sessions.
public struct SparklineChartView: View {
    public let points: [CleanupHistoryPoint]
    
    public init(points: [CleanupHistoryPoint]) {
        self.points = points
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Cleanup Space Trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                if let last = points.last {
                    Text("Latest: \(ByteFormatter.format(last.bytesFreed))")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.green)
                }
            }
            
            if points.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 50)
                    .overlay(
                        Text("No cleanup history yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    )
            } else {
                GeometryReader { geometry in
                    let maxBytes = max(1, points.map { $0.bytesFreed }.max() ?? 1)
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let step = points.count > 1 ? width / CGFloat(points.count - 1) : width
                    
                    Path { path in
                        for (index, point) in points.enumerated() {
                            let x = CGFloat(index) * step
                            let ratio = CGFloat(point.bytesFreed) / CGFloat(maxBytes)
                            let y = height - (ratio * (height - 8)) - 4
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 50)
            }
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
