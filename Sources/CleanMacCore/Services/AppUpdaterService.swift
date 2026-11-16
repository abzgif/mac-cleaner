import Foundation
import AppKit
import Combine

/// Represents a GitHub Release returned by the GitHub REST API.
public struct GitHubRelease: Codable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let publishedAt: String?
    public let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
    
    public var cleanVersion: String {
        tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
    }
}

public struct GitHubAsset: Codable, Sendable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int64
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// States for the in-app software updater.
public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(version: String, notes: String, downloadURL: URL, releasePageURL: URL)
    case downloading(version: String)
    case installing(version: String)
    case failed(String)
}

/// Service and ViewModel that checks GitHub Releases (`abzgif/mac-cleaner`) for updates
/// and downloads, installs, and relaunches the new version directly from within the app.
@MainActor
public final class AppUpdaterViewModel: ObservableObject {
    public static let shared = AppUpdaterViewModel()
    
    public static let repoOwner = "abzgif"
    public static let repoName = "mac-cleaner"
    public static let fallbackVersion = "1.1.0"
    public static let fallbackBuild = "2"
    
    @Published public var state: UpdateState = .idle
    @Published public var autoCheckOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckOnLaunch, forKey: "CleanMac.autoCheckUpdates")
        }
    }
    @Published public var lastCheckedDate: Date? {
        didSet {
            if let date = lastCheckedDate {
                UserDefaults.standard.set(date, forKey: "CleanMac.lastUpdateCheckDate")
            }
        }
    }
    
    public var currentVersion: String {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
            return ver
        }
        return Self.fallbackVersion
    }
    
    public var currentBuild: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, !build.isEmpty {
            return build
        }
        return Self.fallbackBuild
    }
    
    public init() {
        if UserDefaults.standard.object(forKey: "CleanMac.autoCheckUpdates") == nil {
            self.autoCheckOnLaunch = true
        } else {
            self.autoCheckOnLaunch = UserDefaults.standard.bool(forKey: "CleanMac.autoCheckUpdates")
        }
        self.lastCheckedDate = UserDefaults.standard.object(forKey: "CleanMac.lastUpdateCheckDate") as? Date
    }
    
    /// Checks GitHub Releases API for a newer version of CleanMac.
    public func checkForUpdates() {
        guard state != .checking else { return }
        state = .checking
        
        let currentVer = self.currentVersion
        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let apiURL = URL(string: urlString) else {
            state = .failed("Invalid GitHub API URL.")
            return
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                var request = URLRequest(url: apiURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("CleanMac/\(currentVer)", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 15
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.state = .failed("Could not connect to GitHub release server.")
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    self.state = .failed("GitHub API returned status \(httpResponse.statusCode).")
                    return
                }
                
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                self.lastCheckedDate = Date()
                
                let remoteVer = release.cleanVersion
                if Self.isVersion(remoteVer, newerThan: currentVer) {
                    // Prefer .zip archive for silent extraction, fallback to .dmg or release page
                    let preferredAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) ??
                                         release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
                    
                    let downloadURL = URL(string: preferredAsset?.browserDownloadUrl ?? release.htmlUrl) ?? apiURL
                    let releasePageURL = URL(string: release.htmlUrl) ?? apiURL
                    let notes = (release.body?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                        ?? "Bug fixes, safety improvements, and performance enhancements."
                    
                    self.state = .updateAvailable(
                        version: remoteVer,
                        notes: notes,
                        downloadURL: downloadURL,
                        releasePageURL: releasePageURL
                    )
                } else {
                    self.state = .upToDate(currentVersion: currentVer)
                }
            } catch {
                self.state = .failed("Unable to check for updates: \(error.localizedDescription)")
            }
        }
    }
    
    /// Downloads the update archive from GitHub, extracts CleanMac.app, replaces the current app bundle, and relaunches automatically.
    public func downloadAndInstallUpdate(version: String, downloadURL: URL) {
        state = .downloading(version: version)
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let fileManager = FileManager.default
                let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("CleanMacUpdate_\(UUID().uuidString)")
                try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                
                // 1. Download archive
                var request = URLRequest(url: downloadURL)
                request.setValue("CleanMac/\(self.currentVersion)", forHTTPHeaderField: "User-Agent")
                let (tempFileURL, response) = try await URLSession.shared.download(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "CleanMacUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to download update package."])
                }
                
                self.state = .installing(version: version)
                
                let isDMG = downloadURL.pathExtension.lowercased() == "dmg"
                let archivePath = stagingDir.appendingPathComponent(isDMG ? "Update.dmg" : "Update.zip")
                try fileManager.moveItem(at: tempFileURL, to: archivePath)
                
                let extractDir = stagingDir.appendingPathComponent("Extracted")
                try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
                
                // 2. Extract .app bundle from .zip or .dmg
                let extractedAppURL: URL
                if isDMG {
                    extractedAppURL = try Self.extractAppFromDMG(dmgURL: archivePath, destinationDir: extractDir)
                } else {
                    extractedAppURL = try Self.extractAppFromZIP(zipURL: archivePath, destinationDir: extractDir)
                }
                
                // 3. Remove quarantine flags so Gatekeeper allows launching the updated bundle
                let xattrProcess = Process()
                xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProcess.arguments = ["-cr", extractedAppURL.path]
                try? xattrProcess.run()
                xattrProcess.waitUntilExit()
                
                // 4. Determine destination .app path
                let currentBundleURL = Bundle.main.bundleURL
                let targetAppURL: URL
                if currentBundleURL.pathExtension.lowercased() == "app" {
                    targetAppURL = currentBundleURL
                } else {
                    targetAppURL = URL(fileURLWithPath: "/Applications/CleanMac.app")
                }
                
                // 5. Spawn detached updater script that swaps the app bundle after exit and relaunches CleanMac
                try Self.replaceAndRelaunch(newAppURL: extractedAppURL, targetAppURL: targetAppURL)
            } catch {
                self.state = .failed("Update installation failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Compares two semantic version strings (e.g. "1.2.0" vs "1.1.0").
    public nonisolated static func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        let currentParts = current.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
        let maxCount = max(remoteParts.count, currentParts.count)
        
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
    
    // MARK: - Extraction & Replacement Helpers
    
    private nonisolated static func extractAppFromZIP(zipURL: URL, destinationDir: URL) throws -> URL {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zipURL.path, destinationDir.path]
        try ditto.run()
        ditto.waitUntilExit()
        
        guard ditto.terminationStatus == 0 else {
            throw NSError(domain: "CleanMacUpdater", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to unpack ZIP update archive."])
        }
        
        return try findAppBundle(in: destinationDir)
    }
    
    private nonisolated static func extractAppFromDMG(dmgURL: URL, destinationDir: URL) throws -> URL {
        let mountPoint = destinationDir.appendingPathComponent("mnt")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        
        let attach = Process()
        attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attach.arguments = ["attach", dmgURL.path, "-mountpoint", mountPoint.path, "-nobrowse", "-readonly", "-quiet"]
        try attach.run()
        attach.waitUntilExit()
        
        defer {
            let detach = Process()
            detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detach.arguments = ["detach", mountPoint.path, "-force", "-quiet"]
            try? detach.run()
            detach.waitUntilExit()
        }
        
        let mountedApp = try findAppBundle(in: mountPoint)
        let copiedApp = destinationDir.appendingPathComponent("CleanMac.app")
        try FileManager.default.copyItem(at: mountedApp, to: copiedApp)
        return copiedApp
    }
    
    private nonisolated static func findAppBundle(in directory: URL) throws -> URL {
        let directCandidate = directory.appendingPathComponent("CleanMac.app")
        if FileManager.default.fileExists(atPath: directCandidate.path) {
            return directCandidate
        }
        
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        if let found = contents.first(where: { $0.pathExtension.lowercased() == "app" }) {
            return found
        }
        
        throw NSError(domain: "CleanMacUpdater", code: 3, userInfo: [NSLocalizedDescriptionKey: "CleanMac.app not found in downloaded update archive."])
    }
    
    @MainActor
    private static func replaceAndRelaunch(newAppURL: URL, targetAppURL: URL) throws {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let targetParent = targetAppURL.deletingLastPathComponent().path
        let isWritable = FileManager.default.isWritableFile(atPath: targetParent) &&
                         (!FileManager.default.fileExists(atPath: targetAppURL.path) || FileManager.default.isWritableFile(atPath: targetAppURL.path))
        
        if !isWritable {
            // Request administrator privileges to replace bundle in /Applications before relaunching
            let escapedNew = newAppURL.path.replacingOccurrences(of: "\"", with: "\\\"")
            let escapedTarget = targetAppURL.path.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScriptSource = """
            do shell script "rm -rf \\"\(escapedTarget)\\" && mv -f \\"\(escapedNew)\\" \\"\(escapedTarget)\\" && xattr -cr \\"\(escapedTarget)\\"" with administrator privileges
            """
            if let script = NSAppleScript(source: appleScriptSource) {
                var errorInfo: NSDictionary?
                script.executeAndReturnError(&errorInfo)
                if let err = errorInfo {
                    let message = err[NSAppleScript.errorMessage] as? String ?? "Administrator permission was cancelled."
                    throw NSError(domain: "CleanMacUpdater", code: 4, userInfo: [NSLocalizedDescriptionKey: message])
                }
            }
            
            let relaunchScript = """
            (while kill -0 \(currentPID) 2>/dev/null; do sleep 0.2; done; open "\(targetAppURL.path)") &
            """
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", relaunchScript]
            try task.run()
            NSApp.terminate(nil)
            return
        }
        
        // Standard writable replacement & automatic relaunch
        let updaterScript = """
        (
            while kill -0 \(currentPID) 2>/dev/null; do
                sleep 0.2
            done
            rm -rf "\(targetAppURL.path)"
            mv -f "\(newAppURL.path)" "\(targetAppURL.path)"
            xattr -cr "\(targetAppURL.path)"
            open "\(targetAppURL.path)"
        ) >/dev/null 2>&1 &
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", updaterScript]
        try task.run()
        
        NSApp.terminate(nil)
    }
}
