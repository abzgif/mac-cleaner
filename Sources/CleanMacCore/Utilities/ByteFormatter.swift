import Foundation

/// Utility for formatting file and disk sizes into human-readable strings.
public enum ByteFormatter: Sendable {
    
    /// Formats an Int64 byte count into a localized human-readable string (e.g., "1.42 GB").
    public static func format(_ bytes: Int64) -> String {
        return bytes.formatted(.byteCount(style: .file))
    }
    
    /// Formats an Int byte count into a localized human-readable string.
    public static func format(_ bytes: Int) -> String {
        return Int64(bytes).formatted(.byteCount(style: .file))
    }
    
    /// Formats an UInt64 byte count into a localized human-readable string.
    public static func format(_ bytes: UInt64) -> String {
        let safeInt64 = Int64(min(bytes, UInt64(Int64.max)))
        return safeInt64.formatted(.byteCount(style: .file))
    }
}
