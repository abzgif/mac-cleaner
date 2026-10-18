import SwiftUI

/// Interface for executing system maintenance tasks and performance optimizations.
public struct MaintenanceView: View {
    @StateObject private var viewModel = MaintenanceViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Maintenance & Optimization")
                        .font(.title2.weight(.bold))
                    Text("Safely optimize system components, clear caches, and repair system databases.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(viewModel.selectedTasks.count == viewModel.tasks.count ? "Deselect All" : "Select All") {
                        if viewModel.selectedTasks.count == viewModel.tasks.count {
                            viewModel.deselectAll()
                        } else {
                            viewModel.selectAll()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        viewModel.runSelected()
                    } label: {
                        if viewModel.isRunningAll {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Running...")
                            }
                        } else {
                            Label("Run Selected (\(viewModel.selectedTasks.count))", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedTasks.isEmpty || viewModel.isRunningAll)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)
            
            Divider()
            
            // Task List
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(viewModel.tasks) { task in
                        MaintenanceTaskRow(
                            task: task,
                            onToggle: { viewModel.toggleTask(id: task.id) },
                            onRun: { viewModel.runTask(id: task.id) }
                        )
                    }
                }
                .padding(24)
            }
        }
    }
}

private struct MaintenanceTaskRow: View {
    let task: MaintenanceTask
    let onToggle: () -> Void
    let onRun: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle("", isOn: Binding(
                get: { task.isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            // Task Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 36, height: 36)
                
                Image(systemName: task.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            
            // Text details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text(task.category)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(task.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if let result = task.resultMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text(result)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Run Single Action
            if task.isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 50)
            } else {
                Button("Run") {
                    onRun()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 50)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
