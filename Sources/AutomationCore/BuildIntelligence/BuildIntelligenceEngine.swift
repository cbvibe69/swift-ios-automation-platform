import Foundation
import Logging
import Collections

/// Main Build Intelligence Engine that provides smart rebuilds, build time prediction, and intelligent caching
public actor BuildIntelligenceEngine {
    private let logger: Logger
    private let fileChangeAnalyzer: FileChangeAnalyzer
    private let buildCacheManager: BuildCacheManager
    private let buildTimePredictor: BuildTimePredictor
    private let resourceManager: ResourceManager
    
    // Build history and metrics
    private var buildHistory: Deque<BuildMetrics> = []
    private var dependencyGraph: DependencyGraph = DependencyGraph()
    private var isAnalyzing = false
    
    // Performance targets
    private static let maxBuildHistorySize = 100
    private static let buildTimeReductionTarget = 0.30 // 30% reduction goal
    
    public init(
        logger: Logger,
        resourceManager: ResourceManager
    ) {
        self.logger = logger
        self.resourceManager = resourceManager
        self.fileChangeAnalyzer = FileChangeAnalyzer(logger: logger)
        self.buildCacheManager = BuildCacheManager(logger: logger)
        self.buildTimePredictor = BuildTimePredictor(logger: logger)
        
        logger.info("🧠 Build Intelligence Engine initialized")
    }
    
    // MARK: - Public Interface
    
    /// Analyze if a build is needed based on file changes
    public func shouldRebuild(projectPath: String, since lastBuild: Date) async throws -> RebuildRecommendation {
        logger.info("🔍 Analyzing rebuild necessity for project: \(projectPath)")
        
        guard !isAnalyzing else {
            return RebuildRecommendation(
                shouldRebuild: true,
                reason: "Analysis in progress",
                estimatedTimeReduction: 0,
                affectedTargets: []
            )
        }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        return try await resourceManager.executeWithResourceControl {
            // Analyze file changes since last build
            let changedFiles = try await fileChangeAnalyzer.analyzeChanges(
                projectPath: projectPath,
                since: lastBuild
            )
            
            if changedFiles.isEmpty {
                return RebuildRecommendation(
                    shouldRebuild: false,
                    reason: "No changes detected since last successful build",
                    estimatedTimeReduction: 1.0, // 100% time saved by skipping
                    affectedTargets: []
                )
            }
            
            // Analyze impact of changes
            let impactAnalysis = await dependencyGraph.analyzeImpact(
                changedFiles: changedFiles,
                projectPath: projectPath
            )
            
            // Check cache status
            let cacheStatus = await buildCacheManager.analyzeCacheStatus(
                for: impactAnalysis.affectedTargets,
                projectPath: projectPath
            )
            
            // Predict build time if rebuild is needed
            let predictedTime = await buildTimePredictor.predictBuildTime(
                affectedTargets: impactAnalysis.affectedTargets,
                changedFileCount: changedFiles.count,
                cacheHitRate: cacheStatus.hitRate
            )
            
            // Calculate potential time reduction with caching
            let baselineTime = await getAverageBuildTime()
            let timeReduction = max(0, 1 - (predictedTime / baselineTime))
            
            let shouldRebuild = impactAnalysis.requiresRebuild || cacheStatus.hitRate < 0.8
            
            return RebuildRecommendation(
                shouldRebuild: shouldRebuild,
                reason: shouldRebuild ? 
                    "Changes affect \(impactAnalysis.affectedTargets.count) targets (cache hit: \(Int(cacheStatus.hitRate * 100))%)" :
                    "Changes can be handled incrementally",
                estimatedTimeReduction: timeReduction,
                affectedTargets: impactAnalysis.affectedTargets
            )
        }
    }
    
    /// Optimize build configuration based on intelligence
    public func optimizeBuildConfiguration(
        projectPath: String,
        currentConfiguration: BuildConfiguration
    ) async throws -> OptimizedBuildConfiguration {
        logger.info("⚡ Optimizing build configuration for: \(projectPath)")
        
        // Analyze project structure for optimization opportunities
        let projectAnalysis = try await analyzeProjectStructure(projectPath: projectPath)
        
        // Get resource constraints
        let resourceState = await resourceManager.getCurrentResourceState()
        
        // Calculate optimal settings
        let parallelJobs = calculateOptimalParallelJobs(resourceState: resourceState)
        let enabledOptimizations = selectOptimizations(
            for: projectAnalysis,
            resourceConstraints: resourceState
        )
        
        // Predict impact of optimizations
        let timeReduction = await predictOptimizationImpact(
            optimizations: enabledOptimizations,
            projectSize: projectAnalysis.targetCount
        )
        
        return OptimizedBuildConfiguration(
            baseConfiguration: currentConfiguration,
            parallelJobs: parallelJobs,
            optimizations: enabledOptimizations,
            estimatedTimeReduction: timeReduction,
            reasoning: generateOptimizationReasoning(
                projectAnalysis: projectAnalysis,
                resourceState: resourceState
            )
        )
    }
    
    /// Record build completion for learning
    public func recordBuildCompletion(_ metrics: BuildMetrics) async {
        buildHistory.append(metrics)
        
        // Maintain history size limit
        while buildHistory.count > Self.maxBuildHistorySize {
            buildHistory.removeFirst()
        }
        
        // Update dependency graph with build results
        await dependencyGraph.updateFromBuildResults(metrics)
        
        // Train build time predictor
        await buildTimePredictor.updateModel(with: metrics)
        
        // Update cache effectiveness
        await buildCacheManager.recordBuildMetrics(metrics)
        
        logger.info("📊 Recorded build metrics: \(metrics.duration.formatted()) (\(metrics.success ? "success" : "failure"))")
    }
    
    /// Predict build time for given parameters
    public func predictBuildTime(
        affectedTargets: [String],
        changedFileCount: Int,
        cacheHitRate: Double,
        projectPath: String? = nil
    ) async -> TimeInterval {
        return await buildTimePredictor.predictBuildTime(
            affectedTargets: affectedTargets,
            changedFileCount: changedFileCount,
            cacheHitRate: cacheHitRate,
            projectPath: projectPath
        )
    }
    
    /// Predict build time with confidence interval
    public func predictBuildTimeWithConfidence(
        affectedTargets: [String],
        changedFileCount: Int,
        cacheHitRate: Double
    ) async -> PredictionWithConfidence {
        return await buildTimePredictor.predictBuildTimeWithConfidence(
            affectedTargets: affectedTargets,
            changedFileCount: changedFileCount,
            cacheHitRate: cacheHitRate
        )
    }
    
    /// Get current intelligence statistics
    public func getIntelligenceStats() async -> BuildIntelligenceStats {
        let recentBuilds = Array(buildHistory.suffix(10))
        let avgBuildTime = recentBuilds.map(\.duration).reduce(0, +) / max(1, TimeInterval(recentBuilds.count))
        let successRate = Double(recentBuilds.filter(\.success).count) / max(1, Double(recentBuilds.count))
        
        let accuracyStats = await buildTimePredictor.getAccuracyStats()
        
        return BuildIntelligenceStats(
            totalBuildsAnalyzed: buildHistory.count,
            averageBuildTime: avgBuildTime,
            buildSuccessRate: successRate,
            cacheEffectiveness: await buildCacheManager.getEffectivenessStats(),
            predictionAccuracy: accuracyStats.averageAccuracy,
            timeReductionAchieved: await calculateAchievedTimeReduction()
        )
    }
    
    // MARK: - Private Implementation
    
    private func getAverageBuildTime() async -> TimeInterval {
        let recentBuilds = Array(buildHistory.suffix(5))
        guard !recentBuilds.isEmpty else { return 60.0 } // Default 1 minute
        
        return recentBuilds.map(\.duration).reduce(0, +) / TimeInterval(recentBuilds.count)
    }
    
    private func analyzeProjectStructure(projectPath: String) async throws -> ProjectStructureAnalysis {
        // This would analyze the project structure for optimization opportunities
        // For now, return a basic analysis
        return ProjectStructureAnalysis(
            targetCount: 5, // Would be calculated from actual project
            sourceFileCount: 100,
            dependencyDepth: 3,
            complexityScore: 0.7
        )
    }
    
    private func calculateOptimalParallelJobs(resourceState: AutomationCore.ResourceState) -> Int {
        // Calculate based on CPU cores and memory constraints
        let cpuCores = resourceState.cpuCoreCount
        let memoryGB = resourceState.availableMemoryGB
        
        // Conservative formula: use 75% of cores, limited by memory
        let cpuBasedJobs = Int(Double(cpuCores) * 0.75)
        let memoryBasedJobs = max(1, Int(memoryGB / 2)) // 2GB per job
        
        return min(cpuBasedJobs, memoryBasedJobs, 8) // Cap at 8 for stability
    }
    
    private func selectOptimizations(
        for projectAnalysis: ProjectStructureAnalysis,
        resourceConstraints: AutomationCore.ResourceState
    ) -> [BuildOptimization] {
        var optimizations: [BuildOptimization] = []
        
        // Always enable if we have sufficient resources
        if resourceConstraints.cpuCoreCount >= 4 {
            optimizations.append(.parallelCompilation)
        }
        
        if resourceConstraints.availableMemoryGB > 8 {
            optimizations.append(.incrementalCompilation)
            optimizations.append(.wholeProgramOptimization)
        }
        
        if projectAnalysis.targetCount > 3 {
            optimizations.append(.parallelLinking)
        }
        
        return optimizations
    }
    
    private func predictOptimizationImpact(
        optimizations: [BuildOptimization],
        projectSize: Int
    ) async -> Double {
        // Simple heuristic - would be ML-based in full implementation
        var reduction = 0.0
        
        for optimization in optimizations {
            switch optimization {
            case .parallelCompilation:
                reduction += 0.20 // 20% reduction
            case .incrementalCompilation:
                reduction += 0.15 // 15% reduction
            case .wholeProgramOptimization:
                reduction += 0.10 // 10% reduction
            case .parallelLinking:
                reduction += 0.05 // 5% reduction
            }
        }
        
        // Scale by project size (larger projects benefit more)
        let scaleFactor = min(1.5, 1.0 + Double(projectSize) / 20.0)
        return min(0.5, reduction * scaleFactor) // Cap at 50%
    }
    
    private func generateOptimizationReasoning(
        projectAnalysis: ProjectStructureAnalysis,
        resourceState: AutomationCore.ResourceState
    ) -> String {
        var reasons: [String] = []
        
        if resourceState.cpuCoreCount >= 4 {
            reasons.append("Multi-core CPU detected (\(resourceState.cpuCoreCount) cores)")
        }
        
        if resourceState.availableMemoryGB > 8 {
            reasons.append("Sufficient memory for advanced optimizations (\(Int(resourceState.availableMemoryGB))GB)")
        }
        
        if projectAnalysis.targetCount > 3 {
            reasons.append("Multiple targets benefit from parallel processing")
        }
        
        return reasons.joined(separator: "; ")
    }
    
    private func calculateAchievedTimeReduction() async -> Double {
        // Calculate actual time reduction achieved vs baseline
        guard buildHistory.count >= 5 else { return 0.0 }
        
        let recent = Array(buildHistory.suffix(5))
        let baseline = Array(buildHistory.prefix(5))
        
        let recentAvg = recent.map(\.duration).reduce(0, +) / TimeInterval(recent.count)
        let baselineAvg = baseline.map(\.duration).reduce(0, +) / TimeInterval(baseline.count)
        
        return max(0, 1 - (recentAvg / baselineAvg))
    }
}

// MARK: - Supporting Types

public struct RebuildRecommendation: Sendable {
    public let shouldRebuild: Bool
    public let reason: String
    public let estimatedTimeReduction: Double
    public let affectedTargets: [String]
}

public struct OptimizedBuildConfiguration: Sendable {
    public let baseConfiguration: BuildConfiguration
    public let parallelJobs: Int
    public let optimizations: [BuildOptimization]
    public let estimatedTimeReduction: Double
    public let reasoning: String
}

public enum BuildOptimization: CaseIterable, Sendable {
    case parallelCompilation
    case incrementalCompilation
    case wholeProgramOptimization
    case parallelLinking
}

public struct BuildIntelligenceStats: Sendable {
    public let totalBuildsAnalyzed: Int
    public let averageBuildTime: TimeInterval
    public let buildSuccessRate: Double
    public let cacheEffectiveness: Double
    public let predictionAccuracy: Double
    public let timeReductionAchieved: Double
}

public struct BuildMetrics: Sendable {
    public let projectPath: String
    public let duration: TimeInterval
    public let success: Bool
    public let errorCount: Int
    public let warningCount: Int
    public let changedFileCount: Int
    public let timestamp: Date
    public let configuration: BuildConfiguration
    
    public init(
        projectPath: String,
        duration: TimeInterval,
        success: Bool,
        errorCount: Int,
        warningCount: Int,
        changedFileCount: Int,
        timestamp: Date = Date(),
        configuration: BuildConfiguration
    ) {
        self.projectPath = projectPath
        self.duration = duration
        self.success = success
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.changedFileCount = changedFileCount
        self.timestamp = timestamp
        self.configuration = configuration
    }
}

private struct ProjectStructureAnalysis {
    let targetCount: Int
    let sourceFileCount: Int
    let dependencyDepth: Int
    let complexityScore: Double
} 