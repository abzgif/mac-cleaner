import Foundation
import AppKit

/// Helper utility for previewing files using macOS native Quick Look.
public final class QuickLookHelper: Sendable {
    public static let shared = QuickLookHelper()
    
    public init() {}
    
    /// Spawns the native macOS Quick Look window for a given file.
    public func preview(fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            process.arguments = ["-p", fileURL.path]
            
            // Discard stdout/stderr
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            
            try? process.run()
        }
    }
}
