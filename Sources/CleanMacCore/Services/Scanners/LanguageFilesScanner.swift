import Foundation

/// Disabled for safety: modifying files inside .app bundles invalidates macOS Gatekeeper code signatures and breaks self-updating apps.
public final class LanguageFilesScanner: Scannable, Sendable {
    public let category: ScanCategory = .languageFiles
    
    public init() {}
    
    public func scan(onFoundItem: (@Sendable (ScannedItem) -> Void)?) async throws -> [ScannedItem] {
        return []
    }
}
