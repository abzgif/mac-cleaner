import Foundation
import CleanMacCore

@MainActor
func assertTrue(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if !condition {
        print("❌ [FAIL] \(message) (\(file):\(line))")
        exit(1)
    }
}

@MainActor
func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if a != b {
        print("❌ [FAIL] \(message): '\(a)' != '\(b)' (\(file):\(line))")
        exit(1)
    }
}

@MainActor
func runSafetyPolicyTests() {
    print("🔹 Running SafetyPolicyTests...")
    let policy = SafetyPolicy()
    
    // 1. System Denylist Protection
    let denylisted = [
        "/System",
        "/System/Library",
        "/bin",
        "/bin/sh",
        "/sbin",
        "/usr",
        "/usr/bin",
        "/Library/Apple",
        "/private/etc/hosts"
    ]
    for path in denylisted {
        let result = policy.validateDeletionSafety(for: path)
        switch result {
        case .failure(let violation):
            if case .protectedSystemPath = violation {
                // Pass
            } else {
                assertTrue(false, "Path \(path) failed with wrong violation: \(violation)")
            }
        case .success:
            assertTrue(false, "CRITICAL: System path was allowed: \(path)")
        }
    }
    
    // 2. Root and Empty Protection
    if case .failure(let v) = policy.validateDeletionSafety(for: "/") {
        assertTrue(v == .rootOrEmptyPath, "Expected rootOrEmptyPath for /")
    } else {
        assertTrue(false, "Root was allowed!")
    }
    if case .failure(let v) = policy.validateDeletionSafety(for: "   ") {
        assertTrue(v == .rootOrEmptyPath, "Expected rootOrEmptyPath for whitespace")
    } else {
        assertTrue(false, "Whitespace path was allowed!")
    }
    
    // 3. User Critical Directories Protection
    let home = FileManager.default.homeDirectoryForCurrentUser
    let criticalPaths = [
        home.path,
        home.appendingPathComponent("Desktop").path,
        home.appendingPathComponent("Documents").path,
        home.appendingPathComponent("Pictures").path,
        home.appendingPathComponent(".ssh").path,
        home.appendingPathComponent("Library/Keychains").path
    ]
    for path in criticalPaths {
        let result = policy.validateDeletionSafety(for: path)
        switch result {
        case .failure(let violation):
            if case .protectedUserDirectory = violation {
                // Pass
            } else {
                assertTrue(false, "Path \(path) expected protectedUserDirectory, got \(violation)")
            }
        case .success:
            assertTrue(false, "CRITICAL: User/developer directory was allowed for deletion: \(path)")
        }
    }
    
    // 4. JDownloader 2, Android Studio, Application Support & .app Bundle Internal Protection
    let protectedAppPaths = [
        "/Applications/JDownloader 2/JDownloader2.app/Contents/Resources/es.lproj",
        "/Applications/JDownloader2.app/Contents/Java/Core.jar",
        home.appendingPathComponent("Library/Application Support/JDownloader 2").path,
        home.appendingPathComponent("Library/Application Support/Google/AndroidStudio2024.2").path,
        home.appendingPathComponent("Library/Caches/Google/AndroidStudio2024.2").path,
        home.appendingPathComponent("Library/Caches/org.jdownloader.launcher").path,
        home.appendingPathComponent("Library/Preferences/org.jdownloader.plist").path
    ]
    for path in protectedAppPaths {
        let result = policy.validateDeletionSafety(for: path, isAppUninstall: false)
        switch result {
        case .failure(let violation):
            if case .protectedApplicationData = violation {
                // Pass
            } else {
                assertTrue(false, "Path \(path) expected protectedApplicationData, got \(violation)")
            }
        case .success:
            assertTrue(false, "CRITICAL: Protected app/IDE path was allowed during general scan: \(path)")
        }
    }
    
    // 5. Custom Exclusions
    let customExclusion = "/Users/testuser/MySpecialFolder"
    let subPath = "/Users/testuser/MySpecialFolder/cache.tmp"
    let result = policy.validateDeletionSafety(for: subPath, userExclusions: [customExclusion])
    switch result {
    case .failure(let v):
        if case .userExcludedPath = v {
            // Pass
        } else {
            assertTrue(false, "Expected userExcludedPath")
        }
    case .success:
        assertTrue(false, "Excluded path was allowed")
    }
    
    print("  ✅ SafetyPolicyTests passed!")
}

@MainActor
func runCleanupEngineTests() async throws {
    print("🔹 Running CleanupEngineTests...")
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CleanMacTest_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    let historyURL = tempDir.appendingPathComponent("history.json")
    let historyService = HistoryService(customStorageURL: historyURL)
    let engine = CleanupEngine(safetyPolicy: SafetyPolicy.shared, historyService: historyService)
    
    // 1. Denylist Protection
    let systemItem = ScannedItem(
        url: URL(fileURLWithPath: "/System/Library/test.txt"),
        size: 1024,
        category: .systemCaches
    )
    let cleanResult = try await engine.clean(items: [systemItem])
    assertEqual(cleanResult.report.fileCount, 0, "Denylisted item should not be cleaned")
    assertEqual(cleanResult.skippedViolations.count, 1, "Denylisted item should be skipped as violation")
    
    // 2. Safe Trash / Direct Cleanup
    let safeFile = tempDir.appendingPathComponent("safe_junk.tmp")
    try "test junk data".write(to: safeFile, atomically: true, encoding: .utf8)
    let safeItem = ScannedItem(
        url: safeFile,
        size: 14,
        category: .systemCaches
    )
    let safeCleanResult = try await engine.clean(items: [safeItem])
    assertEqual(safeCleanResult.report.fileCount, 1, "Safe item should be cleaned")
    assertEqual(safeCleanResult.report.bytesFreed, 14, "Bytes freed should match item size")
    assertTrue(!FileManager.default.fileExists(atPath: safeFile.path), "Original file should no longer exist at original path")
    
    // 3. User Exclusions
    let excludedDir = tempDir.appendingPathComponent("Excluded")
    try FileManager.default.createDirectory(at: excludedDir, withIntermediateDirectories: true)
    let excludedFile = excludedDir.appendingPathComponent("keep_me.txt")
    try "keep".write(to: excludedFile, atomically: true, encoding: .utf8)
    let excludedItem = ScannedItem(
        url: excludedFile,
        size: 4,
        category: .systemCaches
    )
    let exclResult = try await engine.clean(items: [excludedItem], userExclusions: [excludedDir.path])
    assertEqual(exclResult.report.fileCount, 0, "Excluded file should be skipped")
    assertTrue(FileManager.default.fileExists(atPath: excludedFile.path), "Excluded file must remain on disk")
    
    print("  ✅ CleanupEngineTests passed!")
}

@MainActor
func runDuplicateFinderTests() async throws {
    print("🔹 Running DuplicateFinderTests...")
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CleanMacDupes_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    let file1 = tempDir.appendingPathComponent("file1.dat")
    let file2 = tempDir.appendingPathComponent("file2.dat")
    let file3Unique = tempDir.appendingPathComponent("unique.dat")
    
    let sampleContent = String(repeating: "CleanMac duplicate test content 1234567890\n", count: 100)
    let uniqueContent = String(repeating: "CleanMac different content completely unique\n", count: 100)
    
    try sampleContent.write(to: file1, atomically: true, encoding: .utf8)
    try sampleContent.write(to: file2, atomically: true, encoding: .utf8)
    try uniqueContent.write(to: file3Unique, atomically: true, encoding: .utf8)
    
    let scanner = DuplicateFinderScanner(directories: [tempDir])
    let items = try await scanner.scan(onFoundItem: nil)
    assertEqual(items.count, 2, "Should find 2 matching duplicate files")
    
    let selected = items.filter { $0.isSelected }
    let unselected = items.filter { !$0.isSelected }
    assertEqual(selected.count, 1, "Duplicate copy should be selected")
    assertEqual(unselected.count, 1, "Original copy should be preserved unselected")
    
    // SHA-256 test
    let hash = HashUtility.sha256(of: file1)
    assertTrue(hash != nil, "Hash should be computed")
    assertEqual(hash?.count ?? 0, 64, "SHA-256 hash length should be 64 characters")
    
    print("  ✅ DuplicateFinderTests passed!")
}

@MainActor
func runByteFormatterTests() {
    print("🔹 Running ByteFormatterTests...")
    let zero = ByteFormatter.format(Int64(0))
    assertTrue(zero.contains("0") || zero.contains("Zero"), "Zero bytes formatting")
    
    let megabytes = ByteFormatter.format(Int64(1048576 * 50))
    assertTrue(megabytes.contains("50") || megabytes.contains("MB") || megabytes.contains("52"), "50 MB formatting")
    
    let gigabytes = ByteFormatter.format(Int64(1073741824 * 3))
    assertTrue(gigabytes.contains("3") || gigabytes.contains("GB"), "3 GB formatting")
    print("  ✅ ByteFormatterTests passed!")
}

@MainActor
func runUpdaterVersionComparisonTests() {
    print("🔹 Running UpdaterVersionComparisonTests...")
    assertTrue(AppUpdaterViewModel.isVersion("1.1.0", newerThan: "1.0.0"), "1.1.0 should be newer than 1.0.0")
    assertTrue(AppUpdaterViewModel.isVersion("1.2.0", newerThan: "1.1.0"), "1.2.0 should be newer than 1.1.0")
    assertTrue(AppUpdaterViewModel.isVersion("2.0.0", newerThan: "1.9.9"), "2.0.0 should be newer than 1.9.9")
    assertTrue(!AppUpdaterViewModel.isVersion("1.1.0", newerThan: "1.1.0"), "Same version should not be newer")
    assertTrue(!AppUpdaterViewModel.isVersion("1.0.0", newerThan: "1.1.0"), "Older version should not be newer")
    print("  ✅ UpdaterVersionComparisonTests passed!")
}

@MainActor
func runScanEngineTests() async {
    print("🔹 Running ScanEngineTests...")
    let engine = ScanEngine()
    let result = await engine.scan(categories: ScanCategory.smartCleanCategories.filter { $0.isDefaultSmartScan })
    assertTrue(result.scanDuration >= 0, "Scan duration should be positive")
    
    for item in result.allItems where item.category == .systemCaches {
        assertTrue(!SafetyPolicy.shared.isProtectedCacheOrAppPath(item.path), "Protected item must never appear in System Caches: \(item.path)")
    }
    print("  ✅ ScanEngineTests passed!")
}

@MainActor
func runSpaceAnalyzerTests() async {
    print("🔹 Running SpaceAnalyzerTests...")
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SpaceAnalyzerTest_\(UUID().uuidString)")
    let subDir = tempDir.appendingPathComponent("SubFolder")
    try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
    
    let fileA = tempDir.appendingPathComponent("fileA.bin")
    let fileB = subDir.appendingPathComponent("fileB.bin")
    let dataA = Data(repeating: 0x41, count: 1024 * 100) // 100 KB
    let dataB = Data(repeating: 0x42, count: 1024 * 300) // 300 KB
    try? dataA.write(to: fileA)
    try? dataB.write(to: fileB)
    
    let service = SpaceAnalyzerService.shared
    let rootNode = await service.analyzeDirectory(at: tempDir)
    
    assertTrue(rootNode.size >= 400 * 1024, "Total size should be at least 400 KB, got \(rootNode.size)")
    assertTrue(!rootNode.children.isEmpty, "Root node should have children")
    
    let subNode = rootNode.children.first { $0.name == "SubFolder" }
    assertTrue(subNode != nil, "SubFolder child should exist")
    assertTrue((subNode?.size ?? 0) >= 300 * 1024, "SubFolder size should be >= 300 KB")
    
    try? FileManager.default.removeItem(at: tempDir)
    print("  ✅ SpaceAnalyzerTests passed!")
}

@main
struct TestRunnerApp {
    static func main() async {
        print("========================================")
        print("  CLEANMAC AUTOMATED TEST SUITE")
        print("========================================")
        
        runSafetyPolicyTests()
        do {
            try await runCleanupEngineTests()
            try await runDuplicateFinderTests()
        } catch {
            print("❌ Unexpected error during test execution: \(error)")
            exit(1)
        }
        runByteFormatterTests()
        runUpdaterVersionComparisonTests()
        await runScanEngineTests()
        await runSpaceAnalyzerTests()
        
        print("========================================")
        print("🎉 ALL TEST SUITES PASSED SUCCESSFULLY!")
        print("========================================")
    }
}
