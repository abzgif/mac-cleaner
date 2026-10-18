import Foundation

/// Defines a maintenance script or optimization routine.
public struct MaintenanceTask: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let category: String
    public var isSelected: Bool
    public var isRunning: Bool
    public var isCompleted: Bool
    public var resultMessage: String?
    
    public init(
        id: String,
        title: String,
        subtitle: String,
        iconName: String,
        category: String = "System",
        isSelected: Bool = false,
        isRunning: Bool = false,
        isCompleted: Bool = false,
        resultMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.category = category
        self.isSelected = isSelected
        self.isRunning = isRunning
        self.isCompleted = isCompleted
        self.resultMessage = resultMessage
    }
}
