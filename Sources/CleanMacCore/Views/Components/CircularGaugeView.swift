import SwiftUI

/// An ultra-minimal, elegant circular gauge displaying storage utilization.
public struct CircularGaugeView: View {
    public let usedRatio: Double
    public let usedString: String
    public let freeString: String
    public let totalString: String
    
    public init(
        usedRatio: Double,
        usedString: String,
        freeString: String,
        totalString: String
    ) {
        self.usedRatio = max(0, min(1, usedRatio))
        self.usedString = usedString
        self.freeString = freeString
        self.totalString = totalString
    }
    
    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 10)
            
            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(usedRatio))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: usedRatio)
            
            // Central statistics
            VStack(spacing: 3) {
                Text("\(Int(usedRatio * 100))%")
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(usedString) used")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                
                Text("\(freeString) free")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .frame(width: 190, height: 190)
    }
}
