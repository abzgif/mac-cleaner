import Foundation
import CryptoKit

/// Utility for generating cryptographically secure hashes for duplicate file comparison.
public enum HashUtility {
    private static let bufferSize = 64 * 1024 // 64 KB chunks
    
    /// Computes the SHA-256 hash of the file at the specified URL using streaming chunks.
    ///
    /// - Parameter url: The file URL to hash.
    /// - Returns: Hexadecimal string representation of the SHA-256 digest, or nil if unreadable.
    public static func sha256(of url: URL) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? fileHandle.close()
        }
        
        var hasher = SHA256()
        
        while true {
            guard let data = try? fileHandle.read(upToCount: bufferSize), !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Quickly hashes the initial header and footer of a large file (first 8KB + last 8KB)
    /// to quickly filter candidates before running a full SHA-256.
    public static func quickHash(of url: URL, fileSize: Int64) -> String? {
        guard fileSize > 16 * 1024 else {
            return sha256(of: url)
        }
        
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? fileHandle.close()
        }
        
        var hasher = SHA256()
        
        // Read first 8KB
        if let headData = try? fileHandle.read(upToCount: 8192) {
            hasher.update(data: headData)
        }
        
        // Read last 8KB
        if (try? fileHandle.seek(toOffset: UInt64(max(0, fileSize - 8192)))) != nil {
            if let tailData = try? fileHandle.read(upToCount: 8192) {
                hasher.update(data: tailData)
            }
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
