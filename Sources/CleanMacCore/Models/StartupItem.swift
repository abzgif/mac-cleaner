import Foundation

public enum StartupItemType: String, CaseIterable, Identifiable, Sendable {
    case userAgent = "User Launch Agent"
    case systemAgent = "Global Launch Agent"
    case systemDaemon = "System Daemon"
    
    public var id: String { rawValue }
}

/// Represents a background LaunchAgent or LaunchDaemon that runs on user login or system boot.
public struct StartupItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let label: String
    public let path: URL
    public let programPath: String?
    public let runAtLoad: Bool
    public let isOrphaned: Bool
    public let itemType: StartupItemType
    public var isSelected: Bool
    
    public init(
        id: String,
        name: String,
        label: String,
        path: URL,
        programPath: String?,
        runAtLoad: Bool,
        isOrphaned: Bool,
        itemType: StartupItemType,
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.label = label
        self.path = path
        self.programPath = programPath
        self.runAtLoad = runAtLoad
        self.isOrphaned = isOrphaned
        self.itemType = itemType
        self.isSelected = isSelected
    }
}
