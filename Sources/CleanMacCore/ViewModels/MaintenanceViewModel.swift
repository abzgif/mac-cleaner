import Foundation
import SwiftUI
import Combine

/// ViewModel orchestrating system maintenance routines.
@MainActor
public final class MaintenanceViewModel: ObservableObject {
    @Published public var tasks: [MaintenanceTask] = []
    @Published public var isRunningAll: Bool = false
    @Published public var activeTaskId: String?
    
    private let service = MaintenanceService.shared
    
    public init() {
        self.tasks = service.getAvailableTasks()
    }
    
    public var selectedTasks: [MaintenanceTask] {
        tasks.filter { $0.isSelected }
    }
    
    public func toggleTask(id: String) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].isSelected.toggle()
        }
    }
    
    public func selectAll() {
        for idx in tasks.indices {
            tasks[idx].isSelected = true
        }
    }
    
    public func deselectAll() {
        for idx in tasks.indices {
            tasks[idx].isSelected = false
        }
    }
    
    public func runTask(id: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }), !tasks[idx].isRunning else { return }
        
        tasks[idx].isRunning = true
        tasks[idx].isCompleted = false
        tasks[idx].resultMessage = nil
        activeTaskId = id
        
        Task { [weak self] in
            guard let self = self else { return }
            let res = await self.service.executeTask(id: id)
            if let updateIdx = self.tasks.firstIndex(where: { $0.id == id }) {
                self.tasks[updateIdx].isRunning = false
                self.tasks[updateIdx].isCompleted = true
                self.tasks[updateIdx].resultMessage = res.message
            }
            if self.activeTaskId == id {
                self.activeTaskId = nil
            }
        }
    }
    
    public func runSelected() {
        guard !isRunningAll else { return }
        let toRun = tasks.filter { $0.isSelected }
        guard !toRun.isEmpty else { return }
        
        isRunningAll = true
        
        Task { [weak self] in
            guard let self = self else { return }
            for task in toRun {
                if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[idx].isRunning = true
                    self.tasks[idx].isCompleted = false
                    self.tasks[idx].resultMessage = nil
                    self.activeTaskId = task.id
                }
                
                let res = await self.service.executeTask(id: task.id)
                
                if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[idx].isRunning = false
                    self.tasks[idx].isCompleted = true
                    self.tasks[idx].resultMessage = res.message
                }
            }
            self.activeTaskId = nil
            self.isRunningAll = false
        }
    }
}
