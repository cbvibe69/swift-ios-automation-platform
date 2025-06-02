import Foundation
import Logging
import SystemPackage

/// Intelligent build cache manager that provides smart caching strategies for build optimization
public actor BuildCacheManager {
    private let logger: Logger
    private let cacheDirectory: URL
    private var cacheMetadata: [String: CacheEntry] = [:]
    private var cacheStats = CacheStats()
    
    // Cache configuration
    private static let maxCacheSize: UInt64 = 5_000_000_000 // 5GB
    private static let maxCacheAge: TimeInterval = 7 * 24 * 3600 // 7 days
    private static let cacheVersion = "1.0"
    
    public init(logger: Logger, cacheDirectory: URL? = nil) {
        self.logger = logger
        self.cacheDirectory = cacheDirectory ?? Self.defaultCacheDirectory()
        
        Task {
            await initializeCache()
        }
    }
    
    // MARK: - Public Interface
    
    /// Analyze cache status for given targets
    public func analyzeCacheStatus(
        for targets: [String],
        projectPath: String
    ) async -> CacheAnalysis {
        logger.info("🗄️ Analyzing cache status for \(targets.count) targets")
        
        var hitCount = 0
        var missCount = 0
        var staleCount = 0
        var cacheEntries: [String: CacheEntryStatus] = [:]
        
        for target in targets {
            let cacheKey = generateCacheKey(target: target, projectPath: projectPath)
            let status = await analyzeCacheEntry(cacheKey: cacheKey, target: target)
            
            cacheEntries[target] = status
            
            switch status.state {
            case .hit:
                hitCount += 1
            case .miss:
                missCount += 1
            case .stale:
                staleCount += 1
            }
        }
        
        let hitRate = Double(hitCount) / max(1, Double(targets.count))
        
        return CacheAnalysis(
            hitRate: hitRate,
            totalEntries: targets.count,
            hitCount: hitCount,
            missCount: missCount,
            staleCount: staleCount,
            entries: cacheEntries,
            recommendedActions: await generateCacheRecommendations(hitRate: hitRate, entries: cacheEntries)
        )
    }
    
    /// Store build artifacts in cache
    public func storeBuildArtifacts(
        target: String,
        projectPath: String,
        artifacts: [BuildArtifact],
        buildHash: String
    ) async throws {
        let cacheKey = generateCacheKey(target: target, projectPath: projectPath)
        logger.info("💾 Storing build artifacts for: \(target)")
        
        let targetCacheDir = cacheDirectory.appendingPathComponent(cacheKey)
        try FileManager.default.createDirectory(at: targetCacheDir, withIntermediateDirectories: true)
        
        var storedArtifacts: [StoredArtifact] = []
        var totalSize: UInt64 = 0
        
        for artifact in artifacts {
            do {
                let destinationURL = targetCacheDir.appendingPathComponent(artifact.name)
                try FileManager.default.copyItem(at: artifact.sourceURL, to: destinationURL)
                
                let size = try getFileSize(at: destinationURL)
                totalSize += size
                
                storedArtifacts.append(StoredArtifact(
                    name: artifact.name,
                    path: destinationURL.path,
                    size: size,
                    checksum: try calculateChecksum(for: destinationURL)
                ))
                
                logger.debug("📦 Stored artifact: \(artifact.name) (\(formatBytes(size)))")
            } catch {
                logger.warning("Failed to store artifact \(artifact.name): \(error)")
            }
        }
        
        // Create cache entry
        let cacheEntry = CacheEntry(
            cacheKey: cacheKey,
            target: target,
            projectPath: projectPath,
            buildHash: buildHash,
            artifacts: storedArtifacts,
            totalSize: totalSize,
            createdAt: Date(),
            lastAccessed: Date()
        )
        
        cacheMetadata[cacheKey] = cacheEntry
        await updateCacheStats(entry: cacheEntry, operation: .store)
        
        // Persist metadata
        try await saveCacheMetadata()
        
        // Check if cache cleanup is needed
        await performCacheMaintenanceIfNeeded()
        
        logger.info("✅ Cached \(storedArtifacts.count) artifacts (\(formatBytes(totalSize)))")
    }
    
    /// Retrieve build artifacts from cache
    public func retrieveBuildArtifacts(
        target: String,
        projectPath: String,
        buildHash: String
    ) async throws -> [BuildArtifact]? {
        let cacheKey = generateCacheKey(target: target, projectPath: projectPath)
        
        guard let cacheEntry = cacheMetadata[cacheKey] else {
            cacheStats.missCount += 1
            return nil
        }
        
        // Check if cache entry is still valid
        if cacheEntry.buildHash != buildHash {
            logger.info("🔄 Cache entry stale for \(target) (hash mismatch)")
            cacheStats.staleCount += 1
            return nil
        }
        
        // Check if artifacts still exist
        var artifacts: [BuildArtifact] = []
        for storedArtifact in cacheEntry.artifacts {
            let artifactURL = URL(fileURLWithPath: storedArtifact.path)
            
            if FileManager.default.fileExists(atPath: storedArtifact.path) {
                // Verify checksum
                let currentChecksum = try calculateChecksum(for: artifactURL)
                if currentChecksum == storedArtifact.checksum {
                    artifacts.append(BuildArtifact(
                        name: storedArtifact.name,
                        sourceURL: artifactURL,
                        type: .compiled // Would be more specific in full implementation
                    ))
                } else {
                    logger.warning("⚠️ Checksum mismatch for cached artifact: \(storedArtifact.name)")
                    return nil
                }
            } else {
                logger.warning("⚠️ Cached artifact missing: \(storedArtifact.name)")
                return nil
            }
        }
        
        // Update access time
        cacheMetadata[cacheKey]?.lastAccessed = Date()
        cacheStats.hitCount += 1
        
        logger.info("✅ Retrieved \(artifacts.count) cached artifacts for: \(target)")
        return artifacts
    }
    
    /// Get cache effectiveness statistics
    public func getEffectivenessStats() async -> Double {
        let totalRequests = cacheStats.hitCount + cacheStats.missCount + cacheStats.staleCount
        guard totalRequests > 0 else { return 0.0 }
        
        return Double(cacheStats.hitCount) / Double(totalRequests)
    }
    
    /// Record build metrics for cache optimization
    public func recordBuildMetrics(_ metrics: BuildMetrics) async {
        // Update cache effectiveness based on build results
        if metrics.success {
            cacheStats.successfulBuilds += 1
        } else {
            cacheStats.failedBuilds += 1
        }
        
        // Track build times for cache value analysis
        cacheStats.totalBuildTime += metrics.duration
        cacheStats.buildCount += 1
    }
    
    /// Perform cache maintenance
    public func performMaintenance() async {
        logger.info("🧹 Performing cache maintenance")
        
        await cleanupExpiredEntries()
        await cleanupExcessiveSize()
        await updateCacheStatistics()
        
        try? await saveCacheMetadata()
        
        logger.info("✅ Cache maintenance completed")
    }
    
    /// Get current cache statistics
    public func getCacheStatistics() async -> CacheStatistics {
        let totalSize = cacheMetadata.values.reduce(0) { $0 + $1.totalSize }
        let totalEntries = cacheMetadata.count
        let avgBuildTime = cacheStats.buildCount > 0 ? cacheStats.totalBuildTime / TimeInterval(cacheStats.buildCount) : 0
        
        return CacheStatistics(
            totalEntries: totalEntries,
            totalSize: totalSize,
            hitRate: await getEffectivenessStats(),
            averageBuildTime: avgBuildTime,
            spaceSaved: calculateSpaceSaved(),
            timeSaved: calculateTimeSaved()
        )
    }
    
    // MARK: - Private Implementation
    
    private func initializeCache() async {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try await loadCacheMetadata()
            logger.info("🗄️ Build cache initialized at: \(cacheDirectory.path)")
        } catch {
            logger.error("Failed to initialize cache: \(error)")
        }
    }
    
    private func generateCacheKey(target: String, projectPath: String) -> String {
        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        return "\(projectName)_\(target)_\(Self.cacheVersion)"
    }
    
    private func analyzeCacheEntry(cacheKey: String, target: String) async -> CacheEntryStatus {
        guard let entry = cacheMetadata[cacheKey] else {
            return CacheEntryStatus(state: .miss, reason: "No cache entry found", lastAccessed: nil)
        }
        
        // Check if entry is too old
        let age = Date().timeIntervalSince(entry.createdAt)
        if age > Self.maxCacheAge {
            return CacheEntryStatus(state: .stale, reason: "Cache entry expired", lastAccessed: entry.lastAccessed)
        }
        
        // Check if artifacts still exist
        for artifact in entry.artifacts {
            if !FileManager.default.fileExists(atPath: artifact.path) {
                return CacheEntryStatus(state: .miss, reason: "Cached artifacts missing", lastAccessed: entry.lastAccessed)
            }
        }
        
        return CacheEntryStatus(state: .hit, reason: "Valid cache entry", lastAccessed: entry.lastAccessed)
    }
    
    private func generateCacheRecommendations(
        hitRate: Double,
        entries: [String: CacheEntryStatus]
    ) async -> [CacheRecommendation] {
        var recommendations: [CacheRecommendation] = []
        
        if hitRate < 0.5 {
            recommendations.append(.enableIncrementalBuilds)
            recommendations.append(.optimizeBuildSettings)
        }
        
        if hitRate < 0.3 {
            recommendations.append(.increaseCacheSize)
        }
        
        let staleEntries = entries.values.filter { $0.state == .stale }.count
        if staleEntries > entries.count / 2 {
            recommendations.append(.cleanupStaleEntries)
        }
        
        return recommendations
    }
    
    private func updateCacheStats(entry: CacheEntry, operation: CacheOperation) async {
        switch operation {
        case .store:
            cacheStats.storeCount += 1
            cacheStats.totalStoredSize += entry.totalSize
        case .retrieve:
            cacheStats.retrieveCount += 1
        }
    }
    
    private func performCacheMaintenanceIfNeeded() async {
        let totalSize = cacheMetadata.values.reduce(0) { $0 + $1.totalSize }
        
        if totalSize > Self.maxCacheSize {
            await cleanupExcessiveSize()
        }
        
        // Cleanup every 100 operations
        if (cacheStats.storeCount + cacheStats.retrieveCount) % 100 == 0 {
            await cleanupExpiredEntries()
        }
    }
    
    private func cleanupExpiredEntries() async {
        let now = Date()
        var removedCount = 0
        var removedSize: UInt64 = 0
        
        for (key, entry) in cacheMetadata {
            if now.timeIntervalSince(entry.createdAt) > Self.maxCacheAge {
                await removeCacheEntry(key: key)
                removedCount += 1
                removedSize += entry.totalSize
            }
        }
        
        if removedCount > 0 {
            logger.info("🗑️ Removed \(removedCount) expired cache entries (\(formatBytes(removedSize)))")
        }
    }
    
    private func cleanupExcessiveSize() async {
        let targetSize = UInt64(Double(Self.maxCacheSize) * 0.8) // Reduce to 80% of max
        var currentSize = cacheMetadata.values.reduce(0) { $0 + $1.totalSize }
        
        guard currentSize > targetSize else { return }
        
        // Sort by last accessed (LRU eviction)
        let sortedEntries = cacheMetadata.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        
        var removedCount = 0
        for (key, entry) in sortedEntries {
            if currentSize <= targetSize { break }
            
            await removeCacheEntry(key: key)
            currentSize -= entry.totalSize
            removedCount += 1
        }
        
        logger.info("🗑️ Removed \(removedCount) cache entries to reduce size")
    }
    
    private func removeCacheEntry(key: String) async {
        guard cacheMetadata[key] != nil else { return }
        
        // Remove cache directory
        let entryDir = cacheDirectory.appendingPathComponent(key)
        try? FileManager.default.removeItem(at: entryDir)
        
        // Remove from metadata
        cacheMetadata.removeValue(forKey: key)
    }
    
    private func updateCacheStatistics() async {
        // Update internal statistics
        cacheStats.lastMaintenanceDate = Date()
    }
    
    private func calculateSpaceSaved() -> UInt64 {
        // Estimate space saved through caching
        return UInt64(Double(cacheStats.hitCount) * 100_000_000) // Rough estimate: 100MB per hit
    }
    
    private func calculateTimeSaved() -> TimeInterval {
        // Estimate time saved through caching
        let avgBuildTime = cacheStats.buildCount > 0 ? cacheStats.totalBuildTime / TimeInterval(cacheStats.buildCount) : 60.0
        return TimeInterval(cacheStats.hitCount) * avgBuildTime * 0.7 // 70% time saving estimate
    }
    
    private static func defaultCacheDirectory() -> URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("SwiftAutomationPlatform")
            .appendingPathComponent("BuildCache")
    }
    
    // MARK: - File Operations
    
    private func getFileSize(at url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }
    
    private func calculateChecksum(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return data.sha256
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Persistence
    
    private func saveCacheMetadata() async throws {
        let metadataURL = cacheDirectory.appendingPathComponent("metadata.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(cacheMetadata)
        try data.write(to: metadataURL)
    }
    
    private func loadCacheMetadata() async throws {
        let metadataURL = cacheDirectory.appendingPathComponent("metadata.json")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }
        
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        cacheMetadata = try decoder.decode([String: CacheEntry].self, from: data)
    }
}

// MARK: - Supporting Types

public struct CacheAnalysis: Sendable {
    public let hitRate: Double
    public let totalEntries: Int
    public let hitCount: Int
    public let missCount: Int
    public let staleCount: Int
    public let entries: [String: CacheEntryStatus]
    public let recommendedActions: [CacheRecommendation]
}

public struct CacheEntryStatus: Sendable {
    public let state: CacheState
    public let reason: String
    public let lastAccessed: Date?
}

public enum CacheState: Sendable {
    case hit
    case miss
    case stale
}

public enum CacheRecommendation: Sendable {
    case enableIncrementalBuilds
    case optimizeBuildSettings
    case increaseCacheSize
    case cleanupStaleEntries
}

public struct BuildArtifact: Sendable {
    public let name: String
    public let sourceURL: URL
    public let type: ArtifactType
    
    public init(name: String, sourceURL: URL, type: ArtifactType) {
        self.name = name
        self.sourceURL = sourceURL
        self.type = type
    }
}

public enum ArtifactType: Sendable {
    case compiled
    case linked
    case resource
    case intermediate
}

private struct CacheEntry: Codable, Sendable {
    let cacheKey: String
    let target: String
    let projectPath: String
    let buildHash: String
    let artifacts: [StoredArtifact]
    let totalSize: UInt64
    let createdAt: Date
    var lastAccessed: Date
}

private struct StoredArtifact: Codable, Sendable {
    let name: String
    let path: String
    let size: UInt64
    let checksum: String
}

private enum CacheOperation {
    case store
    case retrieve
}

private struct CacheStats {
    var hitCount = 0
    var missCount = 0
    var staleCount = 0
    var storeCount = 0
    var retrieveCount = 0
    var totalStoredSize: UInt64 = 0
    var successfulBuilds = 0
    var failedBuilds = 0
    var totalBuildTime: TimeInterval = 0
    var buildCount = 0
    var lastMaintenanceDate = Date()
}

public struct CacheStatistics: Sendable {
    public let totalEntries: Int
    public let totalSize: UInt64
    public let hitRate: Double
    public let averageBuildTime: TimeInterval
    public let spaceSaved: UInt64
    public let timeSaved: TimeInterval
}

// MARK: - Data Extension for SHA256

private extension Data {
    var sha256: String {
        // Simple hash implementation for now - would use CryptoKit in production
        let bytes = withUnsafeBytes { Array($0) }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
} 