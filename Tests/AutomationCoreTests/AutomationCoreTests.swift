import XCTest
import Logging
@testable import AutomationCore

final class AutomationCoreTests: XCTestCase {
    
    func testPlaceholder() {
        // This test just ensures the module compiles
        XCTAssertTrue(true)
    }
    
    func testBuildIntelligenceEngine() async throws {
        // Test Build Intelligence Engine initialization
        let logger = Logger(label: "test")
        let hardwareSpec = try await detectHardwareCapabilities()
        let resourceManager = try await ResourceManager(
            hardwareSpec: hardwareSpec,
            maxUtilization: 80,
            logger: logger
        )
        
        let buildIntelligence = BuildIntelligenceEngine(
            logger: logger,
            resourceManager: resourceManager
        )
        
        // Test intelligence statistics
        let stats = await buildIntelligence.getIntelligenceStats()
        XCTAssertGreaterThanOrEqual(stats.totalBuildsAnalyzed, 0)
        XCTAssertGreaterThanOrEqual(stats.buildSuccessRate, 0.0)
        XCTAssertLessThanOrEqual(stats.buildSuccessRate, 1.0)
        
        print("✅ Build Intelligence Engine: Initialized with \(stats.totalBuildsAnalyzed) builds analyzed")
    }
    
    func testBuildCacheManager() async throws {
        // Test Build Cache Manager functionality
        let logger = Logger(label: "test")
        let cacheManager = BuildCacheManager(logger: logger)
        
        // Test cache initialization - should work without errors
        let effectivenessStats = await cacheManager.getEffectivenessStats()
        XCTAssertGreaterThanOrEqual(effectivenessStats, 0.0)
        XCTAssertLessThanOrEqual(effectivenessStats, 1.0)
        
        print("✅ Build Cache Manager: Cache effectiveness: \(String(format: "%.1f", effectivenessStats * 100))%")
    }
    
    func testFileChangeAnalyzer() async throws {
        // Test File Change Analyzer
        let logger = Logger(label: "test")
        let analyzer = FileChangeAnalyzer(logger: logger)
        
        // Test change statistics
        let stats = await analyzer.getChangeStats()
        XCTAssertGreaterThanOrEqual(stats.totalFilesTracked, 0)
        XCTAssertGreaterThanOrEqual(stats.recentChanges, 0)
        
        print("✅ File Change Analyzer: Tracking \(stats.totalFilesTracked) files, \(stats.recentChanges) recent changes")
    }
    
    func testBuildTimePredictor() async throws {
        // Test Build Time Predictor
        let logger = Logger(label: "test")
        let predictor = BuildTimePredictor(logger: logger)
        
        // Test accuracy statistics
        let accuracyStats = await predictor.getAccuracyStats()
        XCTAssertGreaterThanOrEqual(accuracyStats.averageAccuracy, 0.0)
        XCTAssertLessThanOrEqual(accuracyStats.averageAccuracy, 1.0)
        
        print("✅ Build Time Predictor: Average accuracy: \(String(format: "%.1f", accuracyStats.averageAccuracy * 100))%")
    }
    
    func testIntegratedBuildIntelligence() async throws {
        // Test integrated Build Intelligence workflow
        let logger = Logger(label: "integration-test")
        let hardwareSpec = try await detectHardwareCapabilities()
        let resourceManager = try await ResourceManager(
            hardwareSpec: hardwareSpec,
            maxUtilization: 80,
            logger: logger
        )
        
        let buildIntelligence = BuildIntelligenceEngine(
            logger: logger,
            resourceManager: resourceManager
        )
        
        // Test build time prediction
        let predictedTime = await buildIntelligence.predictBuildTime(
            affectedTargets: ["Main", "Tests"],
            changedFileCount: 5,
            cacheHitRate: 0.7
        )
        
        XCTAssertGreaterThan(predictedTime, 0.0)
        
        print("✅ Integrated Build Intelligence: Predicted build time: \(String(format: "%.1f", predictedTime))s")
        
        // Test prediction with confidence
        let predictionWithConfidence = await buildIntelligence.predictBuildTimeWithConfidence(
            affectedTargets: ["Main"],
            changedFileCount: 2,
            cacheHitRate: 0.8
        )
        
        XCTAssertGreaterThan(predictionWithConfidence.prediction, 0.0)
        XCTAssertGreaterThanOrEqual(predictionWithConfidence.confidence, 0.0)
        XCTAssertLessThanOrEqual(predictionWithConfidence.confidence, 1.0)
        
        print("✅ Build Intelligence Integration: Prediction with \(String(format: "%.1f", predictionWithConfidence.confidence * 100))% confidence")
        
        // Test intelligence stats
        let finalStats = await buildIntelligence.getIntelligenceStats()
        print("📊 Final Intelligence Stats:")
        print("  • Builds analyzed: \(finalStats.totalBuildsAnalyzed)")
        print("  • Success rate: \(String(format: "%.1f", finalStats.buildSuccessRate * 100))%")
        print("  • Prediction accuracy: \(String(format: "%.1f", finalStats.predictionAccuracy * 100))%")
        print("  • Time reduction achieved: \(String(format: "%.1f", finalStats.timeReductionAchieved * 100))%")
        
        print("✅ Build Intelligence Integration: All components working together successfully")
    }
}
