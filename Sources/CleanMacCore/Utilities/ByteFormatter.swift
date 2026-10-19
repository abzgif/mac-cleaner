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
    
    /// Formats memory byte count into RAM-standard binary units (e.g., "8 GB", "16 GB", "512 MB").
    public static func formatMemory(_ bytes: UInt64) -> String {
        let safeInt64 = Int64(min(bytes, UInt64(Int64.max)))
        return safeInt64.formatted(.byteCount(style: .memory))
    }
    
    /// Formats memory byte count into RAM-standard binary units.
    public static func formatMemory(_ bytes: Int64) -> String {
        return bytes.formatted(.byteCount(style: .memory))
    }
}
