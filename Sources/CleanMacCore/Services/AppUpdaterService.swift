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
    
    /// Checks GitHub Releases for a newer version of CleanMac, falling back to the rate-limit-free web redirect if the API returns 403/429.
    public func checkForUpdates() {
        guard state != .checking else { return }
        state = .checking
        
        let currentVer = self.currentVersion
        let apiURLString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        let webLatestURLString = "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        
        guard let apiURL = URL(string: apiURLString),
              let webLatestURL = URL(string: webLatestURLString) else {
            state = .failed("Invalid GitHub release URL.")
            return
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // 1. Try GitHub REST API first for rich release notes and exact asset URLs
                var request = URLRequest(url: apiURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("CleanMac/\(currentVer)", forHTTPHeaderField: "User-Agent")
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 12
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self.lastCheckedDate = Date()
                    self.applyReleaseCheckResult(
                        remoteVersion: release.cleanVersion,
                        currentVersion: currentVer,
                        notes: release.body,
                        assets: release.assets,
                        releasePageURL: URL(string: release.htmlUrl) ?? webLatestURL
                    )
                    return
                }
                
                // 2. Fallback: Use GitHub's rate-limit-free /releases/latest redirect when API returns 403/429 or is unavailable
                var webRequest = URLRequest(url: webLatestURL)
                webRequest.httpMethod = "HEAD"
                webRequest.setValue("CleanMac/\(currentVer)", forHTTPHeaderField: "User-Agent")
                webRequest.cachePolicy = .reloadIgnoringLocalCacheData
                webRequest.timeoutInterval = 12
                
                let (_, webResponse) = try await URLSession.shared.data(for: webRequest)
                guard let webHTTP = webResponse as? HTTPURLResponse,
                      (200...399).contains(webHTTP.statusCode),
                      let finalURL = webHTTP.url else {
                    self.state = .failed("Unable to reach GitHub Releases.")
                    return
                }
                
                self.lastCheckedDate = Date()
                let tag = finalURL.lastPathComponent
                let remoteVer = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
                
                // Ensure the redirected URL actually resolved to a tag (e.g. .../releases/tag/v1.2.0)
                guard finalURL.path.contains("/releases/tag/"), !remoteVer.isEmpty, remoteVer.lowercased() != "latest" else {
                    self.state = .upToDate(currentVersion: currentVer)
                    return
                }
                
                let directZipURL = URL(string: "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases/download/\(tag)/CleanMac-\(remoteVer).zip")
                    ?? URL(string: "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases/latest/download/CleanMac.zip")!
                
                if Self.isVersion(remoteVer, newerThan: currentVer) {
                    self.state = .updateAvailable(
                        version: remoteVer,
                        notes: "CleanMac v\(remoteVer) is ready to download and install from GitHub.",
                        downloadURL: directZipURL,
                        releasePageURL: finalURL
                    )
                } else {
                    self.state = .upToDate(currentVersion: currentVer)
                }
            } catch {
                self.state = .failed("Unable to check for updates: \(error.localizedDescription)")
            }
        }
    }
    
    private func applyReleaseCheckResult(
        remoteVersion: String,
        currentVersion: String,
        notes: String?,
        assets: [GitHubAsset],
        releasePageURL: URL
    ) {
        if Self.isVersion(remoteVersion, newerThan: currentVersion) {
            let preferredAsset = assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) ??
                                 assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
            
            let downloadURL = URL(string: preferredAsset?.browserDownloadUrl ?? "") ?? releasePageURL
            let cleanNotes = (notes?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? "Bug fixes, safety improvements, and performance enhancements."
            
            self.state = .updateAvailable(
                version: remoteVersion,
                notes: cleanNotes,
                downloadURL: downloadURL,
                releasePageURL: releasePageURL
            )
        } else {
            self.state = .upToDate(currentVersion: currentVersion)
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
                
                // 1. Download archive (fallback to CleanMac.zip if versioned zip URL 404s)
                var request = URLRequest(url: downloadURL)
                request.setValue("CleanMac/\(self.currentVersion)", forHTTPHeaderField: "User-Agent")
                var (tempFileURL, response) = try await URLSession.shared.download(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404,
                   let fallbackZipURL = URL(string: "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases/latest/download/CleanMac.zip") {
                    var fallbackReq = URLRequest(url: fallbackZipURL)
                    fallbackReq.setValue("CleanMac/\(self.currentVersion)", forHTTPHeaderField: "User-Agent")
                    (tempFileURL, response) = try await URLSession.shared.download(for: fallbackReq)
                }
                
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
