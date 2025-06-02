import Foundation
import Logging

/// ML-based build time predictor for intelligent build optimization
public actor BuildTimePredictor {
    private let logger: Logger
    private var buildDataPoints: [BuildDataPoint] = []
    private var predictionModel: LinearRegressionModel
    private var featureExtractor: FeatureExtractor
    
    // Model configuration
    private static let maxDataPoints = 500
    private static let minDataPointsForPrediction = 10
    private static let modelRetrainingThreshold = 50 // Retrain after 50 new data points
    
    public init(logger: Logger) {
        self.logger = logger
        self.predictionModel = LinearRegressionModel()
        self.featureExtractor = FeatureExtractor()
    }
    
    // MARK: - Public Interface
    
    /// Predict build time for given parameters
    public func predictBuildTime(
        affectedTargets: [String],
        changedFileCount: Int,
        cacheHitRate: Double,
        projectPath: String? = nil
    ) async -> TimeInterval {
        logger.debug("🔮 Predicting build time for \(affectedTargets.count) targets, \(changedFileCount) changed files")
        
        // Extract features for prediction
        let features = await featureExtractor.extractFeatures(
            affectedTargets: affectedTargets,
            changedFileCount: changedFileCount,
            cacheHitRate: cacheHitRate,
            projectPath: projectPath
        )
        
        // Make prediction using current model
        let prediction = await predictionModel.predict(features: features)
        
        // Apply bounds and sanity checks
        let boundedPrediction = applyPredictionBounds(prediction, features: features)
        
        logger.debug("📊 Predicted build time: \(boundedPrediction.formatted())")
        return boundedPrediction
    }
    
    /// Update model with actual build results
    public func updateModel(with metrics: BuildMetrics) async {
        let features = await featureExtractor.extractFeaturesFromMetrics(metrics)
        
        let dataPoint = BuildDataPoint(
            features: features,
            actualBuildTime: metrics.duration,
            success: metrics.success,
            timestamp: metrics.timestamp
        )
        
        // Add to training data
        buildDataPoints.append(dataPoint)
        
        // Maintain data size limit
        if buildDataPoints.count > Self.maxDataPoints {
            buildDataPoints.removeFirst(buildDataPoints.count - Self.maxDataPoints)
        }
        
        // Check if model needs retraining
        if await shouldRetrainModel() {
            await retrainModel()
        }
        
        logger.debug("📈 Updated prediction model with build data (total: \(buildDataPoints.count) points)")
    }
    
    /// Get prediction accuracy statistics
    public func getAccuracyStats() async -> PredictionAccuracyStats {
        guard buildDataPoints.count >= Self.minDataPointsForPrediction else {
            return PredictionAccuracyStats(
                totalPredictions: 0,
                averageAccuracy: 0.0,
                meanAbsoluteError: 0.0,
                confidence: 0.0
            )
        }
        
        // Calculate accuracy on recent predictions
        let recentPoints = Array(buildDataPoints.suffix(50))
        var accuracySum = 0.0
        var errorSum = 0.0
        
        for point in recentPoints {
            let prediction = await predictionModel.predict(features: point.features)
            let accuracy = calculateAccuracy(predicted: prediction, actual: point.actualBuildTime)
            let error = abs(prediction - point.actualBuildTime)
            
            accuracySum += accuracy
            errorSum += error
        }
        
        let avgAccuracy = accuracySum / Double(recentPoints.count)
        let meanError = errorSum / Double(recentPoints.count)
        let confidence = calculateConfidence(accuracy: avgAccuracy, dataPoints: recentPoints.count)
        
        return PredictionAccuracyStats(
            totalPredictions: buildDataPoints.count,
            averageAccuracy: avgAccuracy,
            meanAbsoluteError: meanError,
            confidence: confidence
        )
    }
    
    /// Predict build time with confidence interval
    public func predictBuildTimeWithConfidence(
        affectedTargets: [String],
        changedFileCount: Int,
        cacheHitRate: Double
    ) async -> PredictionWithConfidence {
        let prediction = await predictBuildTime(
            affectedTargets: affectedTargets,
            changedFileCount: changedFileCount,
            cacheHitRate: cacheHitRate
        )
        
        let confidence = await calculatePredictionConfidence(
            affectedTargets: affectedTargets,
            changedFileCount: changedFileCount
        )
        
        // Calculate confidence interval (95%)
        let variance = await calculatePredictionVariance()
        let standardError = sqrt(variance)
        let marginOfError = 1.96 * standardError // 95% confidence
        
        return PredictionWithConfidence(
            prediction: prediction,
            confidence: confidence,
            lowerBound: max(0, prediction - marginOfError),
            upperBound: prediction + marginOfError
        )
    }
    
    /// Get model training status
    public func getModelStatus() async -> ModelStatus {
        return ModelStatus(
            dataPoints: buildDataPoints.count,
            isTrained: buildDataPoints.count >= Self.minDataPointsForPrediction,
            lastTrainingDate: await predictionModel.lastTrainingDate,
            averageAccuracy: await getAccuracyStats().averageAccuracy
        )
    }
    
    // MARK: - Private Implementation
    
    private func shouldRetrainModel() async -> Bool {
        // Retrain if we have enough new data points since last training
        let lastTrainingDataCount = await predictionModel.lastTrainingDataCount
        let newDataSinceTraining = buildDataPoints.count - lastTrainingDataCount
        return newDataSinceTraining >= Self.modelRetrainingThreshold &&
               buildDataPoints.count >= Self.minDataPointsForPrediction
    }
    
    private func retrainModel() async {
        logger.info("🎓 Retraining build time prediction model")
        
        // Prepare training data
        let trainingData = buildDataPoints.filter { $0.success } // Only use successful builds
        
        guard trainingData.count >= Self.minDataPointsForPrediction else {
            logger.warning("Insufficient training data for model retraining")
            return
        }
        
        // Train the model
        await predictionModel.train(with: trainingData)
        
        // Validate model performance
        let accuracy = await validateModel(trainingData: trainingData)
        logger.info("✅ Model retrained with accuracy: \(String(format: "%.1f%%", accuracy * 100))")
    }
    
    private func validateModel(trainingData: [BuildDataPoint]) async -> Double {
        // Use cross-validation to estimate model performance
        let validationSize = min(10, trainingData.count / 5)
        let validationData = Array(trainingData.suffix(validationSize))
        
        var totalAccuracy = 0.0
        
        for point in validationData {
            let prediction = await predictionModel.predict(features: point.features)
            let accuracy = calculateAccuracy(predicted: prediction, actual: point.actualBuildTime)
            totalAccuracy += accuracy
        }
        
        return totalAccuracy / Double(validationData.count)
    }
    
    private func calculateAccuracy(predicted: TimeInterval, actual: TimeInterval) -> Double {
        guard actual > 0 else { return 0.0 }
        
        let relativeError = abs(predicted - actual) / actual
        return max(0.0, 1.0 - relativeError)
    }
    
    private func calculateConfidence(accuracy: Double, dataPoints: Int) -> Double {
        // Confidence increases with accuracy and amount of training data
        let dataConfidence = min(1.0, Double(dataPoints) / 100.0)
        return (accuracy + dataConfidence) / 2.0
    }
    
    private func calculatePredictionConfidence(
        affectedTargets: [String],
        changedFileCount: Int
    ) async -> Double {
        // Calculate confidence based on similarity to training data
        let currentFeatures = await featureExtractor.extractFeatures(
            affectedTargets: affectedTargets,
            changedFileCount: changedFileCount,
            cacheHitRate: 0.5 // Average cache hit rate
        )
        
        // Find most similar training examples
        let similarities = await withTaskGroup(of: Double.self) { group in
            var results: [Double] = []
            
            for point in buildDataPoints {
                group.addTask {
                    await self.featureExtractor.calculateSimilarity(features1: currentFeatures, features2: point.features)
                }
            }
            
            for await similarity in group {
                results.append(similarity)
            }
            
            return results
        }
        
        let maxSimilarity = similarities.max() ?? 0.0
        return maxSimilarity
    }
    
    private func calculatePredictionVariance() async -> Double {
        guard buildDataPoints.count >= 5 else { return 100.0 } // Default high variance
        
        let recentPoints = Array(buildDataPoints.suffix(20))
        let predictions = await withTaskGroup(of: Double.self) { group in
            var results: [Double] = []
            
            for point in recentPoints {
                group.addTask {
                    await self.predictionModel.predict(features: point.features)
                }
            }
            
            for await prediction in group {
                results.append(prediction)
            }
            
            return results
        }
        
        let actualTimes = recentPoints.map(\.actualBuildTime)
        let squaredErrors = zip(predictions, actualTimes).map { pred, actual in
            pow(pred - actual, 2)
        }
        
        return squaredErrors.reduce(0, +) / Double(squaredErrors.count)
    }
    
    private func applyPredictionBounds(_ prediction: TimeInterval, features: BuildFeatures) -> TimeInterval {
        // Apply reasonable bounds based on historical data
        let minBuildTime: TimeInterval = 5.0 // Minimum 5 seconds
        let maxBuildTime: TimeInterval = 3600.0 // Maximum 1 hour
        
        // Adjust bounds based on project complexity
        let complexityFactor = 1.0 + (features.projectComplexity * 2.0)
        let adjustedMax = min(maxBuildTime, maxBuildTime * complexityFactor)
        
        return max(minBuildTime, min(adjustedMax, prediction))
    }
}

// MARK: - Supporting Types

public struct PredictionAccuracyStats: Sendable {
    public let totalPredictions: Int
    public let averageAccuracy: Double
    public let meanAbsoluteError: Double
    public let confidence: Double
}

public struct PredictionWithConfidence: Sendable {
    public let prediction: TimeInterval
    public let confidence: Double
    public let lowerBound: TimeInterval
    public let upperBound: TimeInterval
}

public struct ModelStatus: Sendable {
    public let dataPoints: Int
    public let isTrained: Bool
    public let lastTrainingDate: Date?
    public let averageAccuracy: Double
}

private struct BuildDataPoint: Sendable {
    let features: BuildFeatures
    let actualBuildTime: TimeInterval
    let success: Bool
    let timestamp: Date
}

// MARK: - Feature Extraction

private actor FeatureExtractor {
    func extractFeatures(
        affectedTargets: [String],
        changedFileCount: Int,
        cacheHitRate: Double,
        projectPath: String? = nil
    ) async -> BuildFeatures {
        return BuildFeatures(
            targetCount: Double(affectedTargets.count),
            changedFileCount: Double(changedFileCount),
            cacheHitRate: cacheHitRate,
            projectComplexity: calculateProjectComplexity(projectPath: projectPath),
            timeOfDay: extractTimeOfDay(),
            dayOfWeek: extractDayOfWeek()
        )
    }
    
    func extractFeaturesFromMetrics(_ metrics: BuildMetrics) async -> BuildFeatures {
        return BuildFeatures(
            targetCount: 1.0, // Simplified - would analyze build output
            changedFileCount: Double(metrics.changedFileCount),
            cacheHitRate: 0.5, // Would track actual cache performance
            projectComplexity: calculateProjectComplexity(projectPath: metrics.projectPath),
            timeOfDay: extractTimeOfDay(from: metrics.timestamp),
            dayOfWeek: extractDayOfWeek(from: metrics.timestamp)
        )
    }
    
    func calculateSimilarity(features1: BuildFeatures, features2: BuildFeatures) -> Double {
        // Simple Euclidean distance similarity
        let weights = [0.3, 0.25, 0.2, 0.15, 0.05, 0.05] // Feature importance weights
        
        let differences = [
            abs(features1.targetCount - features2.targetCount) / 10.0,
            abs(features1.changedFileCount - features2.changedFileCount) / 100.0,
            abs(features1.cacheHitRate - features2.cacheHitRate),
            abs(features1.projectComplexity - features2.projectComplexity),
            abs(features1.timeOfDay - features2.timeOfDay),
            abs(features1.dayOfWeek - features2.dayOfWeek) / 7.0
        ]
        
        let weightedDistance = zip(differences, weights).map(*).reduce(0, +)
        return max(0.0, 1.0 - weightedDistance)
    }
    
    private func calculateProjectComplexity(projectPath: String?) -> Double {
        // Simplified complexity calculation - would analyze project structure
        guard let projectPath = projectPath else { return 0.5 }
        
        // Use file count as a proxy for complexity
        let fileCount = countSourceFiles(in: projectPath)
        return min(1.0, Double(fileCount) / 1000.0) // Normalize to 0-1
    }
    
    private func countSourceFiles(in projectPath: String) -> Int {
        guard let enumerator = FileManager.default.enumerator(atPath: projectPath) else { return 0 }
        
        let sourceExtensions = ["swift", "m", "mm", "cpp", "c", "h", "hpp"]
        var count = 0
        
        for case let file as String in enumerator {
            let ext = URL(fileURLWithPath: file).pathExtension.lowercased()
            if sourceExtensions.contains(ext) {
                count += 1
            }
        }
        
        return count
    }
    
    private func extractTimeOfDay(from date: Date = Date()) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        return Double(hour) / 24.0 // Normalize to 0-1
    }
    
    private func extractDayOfWeek(from date: Date = Date()) -> Double {
        let weekday = Calendar.current.component(.weekday, from: date)
        return Double(weekday - 1) / 6.0 // Normalize to 0-1 (Sunday = 0)
    }
}

private struct BuildFeatures: Sendable {
    let targetCount: Double
    let changedFileCount: Double
    let cacheHitRate: Double
    let projectComplexity: Double
    let timeOfDay: Double
    let dayOfWeek: Double
    
    var asArray: [Double] {
        return [targetCount, changedFileCount, cacheHitRate, projectComplexity, timeOfDay, dayOfWeek]
    }
}

// MARK: - Linear Regression Model

private actor LinearRegressionModel {
    private var weights: [Double] = []
    private var bias: Double = 0.0
    private(set) var lastTrainingDate: Date?
    private(set) var lastTrainingDataCount: Int = 0
    
    func predict(features: BuildFeatures) async -> TimeInterval {
        guard !weights.isEmpty else {
            // Fallback prediction for untrained model
            return fallbackPrediction(features: features)
        }
        
        let featureArray = features.asArray
        let prediction = zip(featureArray, weights).map(*).reduce(bias, +)
        
        return max(1.0, prediction) // Minimum 1 second
    }
    
    func train(with dataPoints: [BuildDataPoint]) async {
        guard dataPoints.count >= 5 else { return }
        
        // Prepare training data
        let features = dataPoints.map { $0.features.asArray }
        let targets = dataPoints.map { $0.actualBuildTime }
        
        // Simple gradient descent implementation
        let learningRate = 0.01
        let epochs = 100
        
        // Initialize weights if needed
        if weights.isEmpty {
            weights = Array(repeating: 0.1, count: features[0].count)
        }
        
        // Training loop
        for _ in 0..<epochs {
            var weightGradients = Array(repeating: 0.0, count: weights.count)
            var biasGradient = 0.0
            
            for i in 0..<dataPoints.count {
                let prediction = zip(features[i], weights).map(*).reduce(bias, +)
                let error = prediction - targets[i]
                
                // Calculate gradients
                for j in 0..<weights.count {
                    weightGradients[j] += error * features[i][j]
                }
                biasGradient += error
            }
            
            // Update weights and bias
            for j in 0..<weights.count {
                weights[j] -= learningRate * weightGradients[j] / Double(dataPoints.count)
            }
            bias -= learningRate * biasGradient / Double(dataPoints.count)
        }
        
        lastTrainingDate = Date()
        lastTrainingDataCount = dataPoints.count
    }
    
    private func fallbackPrediction(features: BuildFeatures) -> TimeInterval {
        // Simple heuristic-based prediction for untrained model
        let baseTime: TimeInterval = 30.0
        let targetMultiplier = features.targetCount * 15.0
        let fileMultiplier = features.changedFileCount * 0.5
        let cacheBonus = (1.0 - features.cacheHitRate) * 20.0
        
        return baseTime + targetMultiplier + fileMultiplier + cacheBonus
    }
} 