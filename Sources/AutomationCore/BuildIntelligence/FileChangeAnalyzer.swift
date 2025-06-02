import Foundation
import Logging
import Collections

/// Intelligent file change analyzer that determines impact of changes for smart rebuilds
public actor FileChangeAnalyzer {
    private let logger: Logger
    private var fileChangeCache: [String: FileChangeInfo] = [:]
    
    // File type analysis patterns
    private static let sourceFileExtensions: Set<String> = [
        "swift", "m", "mm", "cpp", "c", "cc", "cxx", "h", "hpp"
    ]
    
    private static let resourceFileExtensions: Set<String> = [
        "storyboard", "xib", "plist", "json", "strings", "png", "jpg", "jpeg"
    ]
    
    private static let buildFileExtensions: Set<String> = [
        "xcodeproj", "xcworkspace", "pbxproj", "entitlements"
    ]
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    // MARK: - Public Interface
    
    /// Analyze file changes since a specific date
    public func analyzeChanges(
        projectPath: String,
        since lastBuild: Date
    ) async throws -> [FileChangeInfo] {
        logger.info("🔍 Analyzing file changes since: \(lastBuild.formatted())")
        
        let projectURL = URL(fileURLWithPath: projectPath)
        var changedFiles: [FileChangeInfo] = []
        
        // Use FileManager's efficient directory enumeration
        if let enumerator = FileManager.default.enumerator(
            at: projectURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [
                        .contentModificationDateKey, .fileSizeKey, .isDirectoryKey
                    ])
                    
                    // Skip directories
                    if resourceValues.isDirectory == true { continue }
                    
                    // Check modification date
                    if let modificationDate = resourceValues.contentModificationDate,
                       modificationDate > lastBuild {
                        
                        let changeInfo = await analyzeFileChange(
                            fileURL: fileURL,
                            modificationDate: modificationDate,
                            fileSize: resourceValues.fileSize ?? 0
                        )
                        
                        changedFiles.append(changeInfo)
                    }
                } catch {
                    logger.warning("Failed to analyze file: \(fileURL.path) - \(error)")
                }
            }
        }
        
        // Sort by impact priority (high impact first)
        changedFiles.sort { $0.impactScore > $1.impactScore }
        
        logger.info("📊 Found \(changedFiles.count) changed files")
        return changedFiles
    }
    
    /// Analyze impact of specific file changes
    public func analyzeImpact(
        changedFiles: [FileChangeInfo],
        projectPath: String
    ) async -> ChangeImpactAnalysis {
        logger.info("🎯 Analyzing impact of \(changedFiles.count) file changes")
        
        var affectedTargets: Set<String> = []
        var requiresFullRebuild = false
        var impactLevel: ImpactLevel = .minimal
        
        for file in changedFiles {
            let fileImpact = await analyzeFileImpact(file, in: projectPath)
            
            affectedTargets.formUnion(fileImpact.affectedTargets)
            
            if fileImpact.requiresFullRebuild {
                requiresFullRebuild = true
                impactLevel = .critical
            } else if fileImpact.impactLevel.rawValue > impactLevel.rawValue {
                impactLevel = fileImpact.impactLevel
            }
        }
        
        return ChangeImpactAnalysis(
            affectedTargets: Array(affectedTargets),
            requiresRebuild: !changedFiles.isEmpty,
            impactLevel: impactLevel,
            estimatedRebuildTime: await estimateRebuildTime(
                affectedTargets: Array(affectedTargets),
                impactLevel: impactLevel
            ),
            changedFileCategories: categorizeChangedFiles(changedFiles)
        )
    }
    
    /// Get file change statistics
    public func getChangeStats() async -> FileChangeStats {
        let totalTracked = fileChangeCache.count
        let recentChanges = fileChangeCache.values.filter { 
            $0.lastModified.timeIntervalSinceNow > -3600 // Last hour
        }
        
        return FileChangeStats(
            totalFilesTracked: totalTracked,
            recentChanges: recentChanges.count,
            highImpactFiles: recentChanges.filter { $0.impactScore > 0.8 }.count
        )
    }
    
    // MARK: - Private Implementation
    
    private func analyzeFileChange(
        fileURL: URL,
        modificationDate: Date,
        fileSize: Int
    ) async -> FileChangeInfo {
        let filePath = fileURL.path
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Determine file type and impact
        let fileType = determineFileType(fileExtension: fileExtension)
        let impactScore = calculateImpactScore(
            fileType: fileType,
            fileName: fileName,
            fileSize: fileSize
        )
        
        let changeInfo = FileChangeInfo(
            path: filePath,
            fileName: fileName,
            fileType: fileType,
            lastModified: modificationDate,
            fileSize: fileSize,
            impactScore: impactScore
        )
        
        // Cache for future analysis
        fileChangeCache[filePath] = changeInfo
        
        return changeInfo
    }
    
    private func analyzeFileImpact(
        _ file: FileChangeInfo,
        in projectPath: String
    ) async -> FileImpactAnalysis {
        var affectedTargets: [String] = []
        var requiresFullRebuild = false
        var impactLevel: ImpactLevel = .minimal
        
        switch file.fileType {
        case .sourceCode:
            // Source code changes typically affect the containing target
            affectedTargets = await findTargetsContaining(file.path, in: projectPath)
            impactLevel = .moderate
            
            // Check if it's a critical file (main.swift, AppDelegate, etc.)
            if file.fileName.contains("main") || file.fileName.contains("AppDelegate") {
                impactLevel = .significant
            }
            
        case .buildConfiguration:
            // Build file changes require full rebuild
            requiresFullRebuild = true
            impactLevel = .critical
            affectedTargets = ["All"] // All targets affected
            
        case .resources:
            // Resource changes might only need resource copying
            affectedTargets = await findTargetsContaining(file.path, in: projectPath)
            impactLevel = .minimal
            
        case .headers:
            // Header changes can have wide impact
            affectedTargets = await findDependentTargets(for: file.path, in: projectPath)
            impactLevel = .significant
            
        case .other:
            impactLevel = .minimal
        }
        
        return FileImpactAnalysis(
            affectedTargets: affectedTargets,
            requiresFullRebuild: requiresFullRebuild,
            impactLevel: impactLevel
        )
    }
    
    private func determineFileType(fileExtension: String) -> FileType {
        if Self.sourceFileExtensions.contains(fileExtension) {
            return .sourceCode
        } else if Self.buildFileExtensions.contains(fileExtension) {
            return .buildConfiguration
        } else if Self.resourceFileExtensions.contains(fileExtension) {
            return .resources
        } else if fileExtension == "h" || fileExtension == "hpp" {
            return .headers
        } else {
            return .other
        }
    }
    
    private func calculateImpactScore(
        fileType: FileType,
        fileName: String,
        fileSize: Int
    ) -> Double {
        var score = 0.0
        
        // Base score by file type
        switch fileType {
        case .buildConfiguration:
            score = 1.0 // Highest impact
        case .headers:
            score = 0.8
        case .sourceCode:
            score = 0.6
        case .resources:
            score = 0.3
        case .other:
            score = 0.1
        }
        
        // Adjust for special files
        if fileName.contains("main") || fileName.contains("AppDelegate") {
            score = min(1.0, score + 0.2)
        }
        
        // Large files have higher impact
        if fileSize > 10_000 { // 10KB
            score = min(1.0, score + 0.1)
        }
        
        return score
    }
    
    private func findTargetsContaining(
        _ filePath: String,
        in projectPath: String
    ) async -> [String] {
        // Simplified target detection - would parse .xcodeproj in full implementation
        let relativePath = filePath.replacingOccurrences(of: projectPath, with: "")
        
        // Basic heuristic based on directory structure
        if relativePath.contains("/Tests/") {
            return ["Tests"]
        } else if relativePath.contains("/UI/") {
            return ["UITarget"]
        } else {
            return ["Main"] // Default main target
        }
    }
    
    private func findDependentTargets(
        for headerPath: String,
        in projectPath: String
    ) async -> [String] {
        // Header files can affect multiple targets
        // This would analyze #import/#include statements in full implementation
        return ["Main", "Tests"] // Conservative approach
    }
    
    private func estimateRebuildTime(
        affectedTargets: [String],
        impactLevel: ImpactLevel
    ) async -> TimeInterval {
        // Simple estimation formula
        let baseTime: TimeInterval = 30.0 // 30 seconds base
        let targetMultiplier = Double(affectedTargets.count)
        let impactMultiplier = Double(impactLevel.rawValue + 1)
        
        return baseTime * targetMultiplier * impactMultiplier
    }
    
    private func categorizeChangedFiles(
        _ changedFiles: [FileChangeInfo]
    ) -> [FileType: Int] {
        var categories: [FileType: Int] = [:]
        
        for file in changedFiles {
            categories[file.fileType, default: 0] += 1
        }
        
        return categories
    }
}

// MARK: - Supporting Types

public struct FileChangeInfo: Sendable {
    public let path: String
    public let fileName: String
    public let fileType: FileType
    public let lastModified: Date
    public let fileSize: Int
    public let impactScore: Double
}

public enum FileType: CaseIterable, Sendable {
    case sourceCode
    case headers
    case resources
    case buildConfiguration
    case other
}

public enum ImpactLevel: Int, CaseIterable, Sendable {
    case minimal = 0
    case moderate = 1
    case significant = 2
    case critical = 3
}

public struct ChangeImpactAnalysis: Sendable {
    public let affectedTargets: [String]
    public let requiresRebuild: Bool
    public let impactLevel: ImpactLevel
    public let estimatedRebuildTime: TimeInterval
    public let changedFileCategories: [FileType: Int]
}

private struct FileImpactAnalysis {
    let affectedTargets: [String]
    let requiresFullRebuild: Bool
    let impactLevel: ImpactLevel
}

public struct FileChangeStats: Sendable {
    public let totalFilesTracked: Int
    public let recentChanges: Int
    public let highImpactFiles: Int
}

// MARK: - Dependency Graph Support

public actor DependencyGraph {
    private var dependencies: [String: Set<String>] = [:]
    
    public init() {}
    
    public func analyzeImpact(
        changedFiles: [FileChangeInfo],
        projectPath: String
    ) async -> ChangeImpactAnalysis {
        // Simplified implementation - would build actual dependency graph
        let affectedTargets = changedFiles.flatMap { file in
            switch file.fileType {
            case .buildConfiguration:
                return ["All"]
            case .sourceCode, .headers:
                return ["Main"]
            case .resources:
                return ["Main"]
            case .other:
                return []
            }
        }
        
        let impactLevel: ImpactLevel = changedFiles.contains { $0.fileType == .buildConfiguration } ? .critical : .moderate
        
        return ChangeImpactAnalysis(
            affectedTargets: Array(Set(affectedTargets)),
            requiresRebuild: !changedFiles.isEmpty,
            impactLevel: impactLevel,
            estimatedRebuildTime: TimeInterval(affectedTargets.count * 30),
            changedFileCategories: changedFiles.reduce(into: [:]) { result, file in
                result[file.fileType, default: 0] += 1
            }
        )
    }
    
    public func updateFromBuildResults(_ metrics: BuildMetrics) async {
        // Update dependency graph based on build results
        // Would analyze compilation order and dependencies in full implementation
    }
} 