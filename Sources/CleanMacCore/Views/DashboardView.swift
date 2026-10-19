import SwiftUI

/// Main dashboard view presenting real-time storage gauge, live hardware meters, and historical trends.
public struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PermissionBannerView()
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                StorageGaugeSection(viewModel: viewModel) {
                    appState.selectedTab = .smartScan
                }
                
                HardwareMetersSection(viewModel: viewModel)
                
                StorageSummaryCards(viewModel: viewModel)
                
                SparklineChartView(points: viewModel.sparklinePoints)
                    .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .onAppear {
            viewModel.refresh()
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

// MARK: - Storage Gauge Section

private struct StorageGaugeSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onStartScan: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            CircularGaugeView(
                usedRatio: viewModel.diskUsage.usedRatio,
                usedString: viewModel.diskUsage.formattedUsed,
                freeString: viewModel.diskUsage.formattedFree,
                totalString: viewModel.diskUsage.formattedTotal
            )
            .padding(.top, 8)
            
            Text("Macintosh HD")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            Button {
                onStartScan()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Start Smart Scan")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Hardware Meters Section

private struct HardwareMetersSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIVE SYSTEM HEALTH")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal)
            
            HStack(spacing: 14) {
                MemoryCardView(viewModel: viewModel)
                CPUCardView(viewModel: viewModel)
            }
            .padding(.horizontal)
        }
    }
}

private struct MemoryCardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.08))
                        .frame(width: 32, height: 32)
                    Image(systemName: "memorychip")
                        .foregroundColor(.purple)
                        .font(.system(size: 14))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Memory (RAM)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(viewModel.memoryStats.formattedUsed) / \(viewModel.memoryStats.formattedTotal)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                Button {
                    viewModel.freeRAM()
                } label: {
                    if viewModel.isPurgingRAM {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("Free RAM")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isPurgingRAM)
            }
            
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(ramColor(for: viewModel.memoryStats))
                            .frame(width: max(geo.size.width * CGFloat(viewModel.memoryStats.pressureRatio), 4), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("\(viewModel.memoryStats.pressurePercentage)% used")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let msg = viewModel.freedRAMMessage {
                        Text(msg)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text("Available: \(viewModel.memoryStats.formattedFree)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func ramColor(for stats: MemoryStats) -> Color {
        if stats.pressureLevel >= 4 { return .red }
        if stats.pressureLevel == 2 || stats.pressureRatio > 0.90 { return .orange }
        return .purple
    }
}

private struct CPUCardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cpuColor(for: viewModel.cpuStats.totalUsedRatio).opacity(0.08))
                        .frame(width: 32, height: 32)
                    Image(systemName: "cpu")
                        .foregroundColor(cpuColor(for: viewModel.cpuStats.totalUsedRatio))
                        .font(.system(size: 14))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Processor (CPU)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(viewModel.cpuStats.totalPercentage)% Load")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                
                Spacer()
            }
            
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(cpuColor(for: viewModel.cpuStats.totalUsedRatio))
                            .frame(width: max(geo.size.width * CGFloat(viewModel.cpuStats.totalUsedRatio), 4), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("User: \(viewModel.cpuStats.userPercentage)%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("System: \(viewModel.cpuStats.systemPercentage)%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func cpuColor(for ratio: Double) -> Color {
        if ratio > 0.80 { return .red }
        if ratio > 0.45 { return .orange }
        return .blue
    }
}

// MARK: - Storage Summary Cards

private struct StorageSummaryCards: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        HStack(spacing: 14) {
            MetricCard(
                title: "Available Free Space",
                value: viewModel.diskUsage.formattedFree,
                subtitle: "\(Int(viewModel.diskUsage.freeRatio * 100))% available",
                icon: "internaldrive",
                color: .green
            )
            
            MetricCard(
                title: "Total Cleaned to Date",
                value: ByteFormatter.format(viewModel.totalFreedBytes),
                subtitle: "\(viewModel.recentReports.count) sessions completed",
                icon: "trash.circle.fill",
                color: .accentColor
            )
        }
        .padding(.horizontal)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.08))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
