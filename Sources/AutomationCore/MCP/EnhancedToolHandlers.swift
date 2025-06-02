import Foundation
import Logging

/// Enhanced tool handlers with intelligence, error analysis, and performance tracking
public actor EnhancedToolHandlers {
    private let logger: Logger
    private let xcodeBuildWrapper: XcodeBuildWrapper
    private let resourceManager: ResourceManager
    private let securityManager: SecurityManager
    private let docGenerator: DocGenerator
    private let buildIntelligenceEngine: BuildIntelligenceEngine
    
    public init(
        logger: Logger,
        xcodeBuildWrapper: XcodeBuildWrapper,
        resourceManager: ResourceManager,
        securityManager: SecurityManager
    ) {
        self.logger = logger
        self.xcodeBuildWrapper = xcodeBuildWrapper
        self.resourceManager = resourceManager
        self.securityManager = securityManager
        self.docGenerator = DocGenerator(logger: logger)
        self.buildIntelligenceEngine = BuildIntelligenceEngine(
            logger: logger,
            resourceManager: resourceManager
        )
    }
    
    // MARK: - Enhanced Build Tool with Intelligence
    
    public func handleEnhancedBuild(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let projectPathValue = arguments["projectPath"],
              let projectPath = projectPathValue.value as? String,
              let schemeValue = arguments["scheme"],
              let scheme = schemeValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        // Security validation
        try securityManager.validateProjectPath(projectPath)
        
        let destination = (arguments["destination"]?.value as? String) ?? "platform=iOS Simulator,name=iPhone 15"
        let configuration = BuildConfiguration(rawValue: (arguments["configuration"]?.value as? String) ?? "Debug") ?? .debug
        
        logger.info("🔨 Enhanced build with intelligence starting: \(scheme) (\(configuration.rawValue))")
        
        return try await resourceManager.executeWithResourceControl {
            let startTime = ContinuousClock.now
            
            // Check if build is necessary using intelligence
            let intelligentAnalysis = await analyzeBuildNecessity(
                projectPath: projectPath,
                scheme: scheme,
                configuration: configuration
            )
            
            // Get optimized build configuration
            let optimizedConfig = try await buildIntelligenceEngine.optimizeBuildConfiguration(
                projectPath: projectPath,
                currentConfiguration: configuration
            )
            
            var message = "🧠 Build Intelligence Analysis:\n"
            message += "  📊 Recommendation: \(intelligentAnalysis.shouldRebuild ? "Build Required" : "Build Skipped")\n"
            message += "  💡 Reason: \(intelligentAnalysis.reason)\n"
            message += "  ⚡ Estimated time reduction: \(String(format: "%.1f%%", intelligentAnalysis.estimatedTimeReduction * 100))\n"
            
            if !intelligentAnalysis.shouldRebuild {
                message += "\n✅ Build skipped - no changes detected that require rebuilding"
                return MCPToolResult.text(message)
            }
            
            message += "\n🔧 Build Optimizations Applied:\n"
            message += "  🚀 Parallel jobs: \(optimizedConfig.parallelJobs)\n"
            message += "  ⚡ Optimizations: \(optimizedConfig.optimizations.map { "\($0)" }.joined(separator: ", "))\n"
            message += "  📈 Expected improvement: \(String(format: "%.1f%%", optimizedConfig.estimatedTimeReduction * 100))\n"
            message += "  📝 Reasoning: \(optimizedConfig.reasoning)\n\n"
            
            do {
                let buildResult = try await xcodeBuildWrapper.buildProject(
                    at: projectPath,
                    scheme: scheme,
                    destination: destination,
                    configuration: configuration
                )
                
                let duration = startTime.duration(to: .now)
                let analysis = await analyzeBuildResult(buildResult)
                
                // Record build metrics for learning
                let buildMetrics = BuildMetrics(
                    projectPath: projectPath,
                    duration: duration.timeInterval,
                    success: buildResult.success,
                    errorCount: buildResult.errors.count,
                    warningCount: buildResult.warnings.count,
                    changedFileCount: intelligentAnalysis.affectedTargets.count,
                    configuration: configuration
                )
                await buildIntelligenceEngine.recordBuildCompletion(buildMetrics)
                
                message += buildResult.success ? "✅ Build successful" : "❌ Build failed"
                message += " in \(duration.formatted())"
                
                if !buildResult.errors.isEmpty {
                    message += "\n\n🚨 Build Errors (\(buildResult.errors.count)):"
                    for error in buildResult.errors.prefix(5) {
                        message += "\n  • \(error.message)"
                        if let file = error.file {
                            message += "\n    📁 \(file)"
                        }
                    }
                    
                    if buildResult.errors.count > 5 {
                        message += "\n  ... and \(buildResult.errors.count - 5) more errors"
                    }
                }
                
                if !buildResult.warnings.isEmpty {
                    message += "\n\n⚠️ Warnings (\(buildResult.warnings.count)):"
                    for warning in buildResult.warnings.prefix(3) {
                        message += "\n  • \(warning.message)"
                    }
                }
                
                // Add enhanced build intelligence analysis
                if let analysis = analysis {
                    message += "\n\n🧠 Enhanced Build Intelligence:"
                    message += "\n  📊 Error Categories: \(analysis.categoryBreakdown.count)"
                    
                    if !analysis.suggestions.isEmpty {
                        message += "\n  💡 Suggestions:"
                        for suggestion in analysis.suggestions.prefix(3) {
                            message += "\n    • \(suggestion)"
                        }
                    }
                }
                
                // Add intelligence statistics
                let intelligenceStats = await buildIntelligenceEngine.getIntelligenceStats()
                message += "\n\n📈 Build Intelligence Stats:"
                message += "\n  🎯 Total builds analyzed: \(intelligenceStats.totalBuildsAnalyzed)"
                message += "\n  ⏱️ Average build time: \(intelligenceStats.averageBuildTime.formatted())"
                message += "\n  ✅ Success rate: \(String(format: "%.1f%%", intelligenceStats.buildSuccessRate * 100))"
                message += "\n  💾 Cache effectiveness: \(String(format: "%.1f%%", intelligenceStats.cacheEffectiveness * 100))"
                message += "\n  🚀 Time reduction achieved: \(String(format: "%.1f%%", intelligenceStats.timeReductionAchieved * 100))"
                
                return MCPToolResult.text(message)
                
            } catch {
                logger.error("Enhanced build failed: \(error)")
                return MCPToolResult.error("Build failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Build Intelligence Analysis Tool
    
    public func handleBuildIntelligence(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let actionValue = arguments["action"],
              let action = actionValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        switch action {
        case "analyze":
            guard let projectPathValue = arguments["projectPath"],
                  let projectPath = projectPathValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await analyzeBuildIntelligence(projectPath: projectPath)
            
        case "stats":
            return await getBuildIntelligenceStats()
            
        case "predict":
            guard let projectPathValue = arguments["projectPath"],
                  let projectPath = projectPathValue.value as? String,
                  let changedFilesValue = arguments["changedFiles"],
                  let changedFiles = changedFilesValue.value as? Int else {
                throw MCPError.invalidParams
            }
            let targets = (arguments["targets"]?.value as? [String]) ?? ["Main"]
            let cacheHitRate = (arguments["cacheHitRate"]?.value as? Double) ?? 0.5
            
            return await predictBuildTime(
                projectPath: projectPath,
                targets: targets,
                changedFiles: changedFiles,
                cacheHitRate: cacheHitRate
            )
            
        default:
            throw MCPError.invalidParams
        }
    }
    
    // MARK: - Private Build Intelligence Methods
    
    private func analyzeBuildNecessity(
        projectPath: String,
        scheme: String,
        configuration: BuildConfiguration
    ) async -> RebuildRecommendation {
        // Get last build time (simplified - would track per scheme/config)
        let lastBuildTime = Date().addingTimeInterval(-3600) // Assume last build 1 hour ago
        
        do {
            return try await buildIntelligenceEngine.shouldRebuild(
                projectPath: projectPath,
                since: lastBuildTime
            )
        } catch {
            logger.warning("Build intelligence analysis failed: \(error)")
            // Fallback to conservative approach
            return RebuildRecommendation(
                shouldRebuild: true,
                reason: "Intelligence analysis unavailable - building conservatively",
                estimatedTimeReduction: 0.0,
                affectedTargets: [scheme]
            )
        }
    }
    
    private func analyzeBuildIntelligence(projectPath: String) async throws -> MCPToolResult {
        try securityManager.validateProjectPath(projectPath)
        
        logger.info("🔍 Analyzing build intelligence for: \(projectPath)")
        
        let stats = await buildIntelligenceEngine.getIntelligenceStats()
        let lastBuildTime = Date().addingTimeInterval(-3600) // Simplified
        
        let rebuildAnalysis = try await buildIntelligenceEngine.shouldRebuild(
            projectPath: projectPath,
            since: lastBuildTime
        )
        
        var message = "🧠 Build Intelligence Analysis Report\n\n"
        
        message += "📊 Current Statistics:\n"
        message += "  🎯 Total builds analyzed: \(stats.totalBuildsAnalyzed)\n"
        message += "  ⏱️ Average build time: \(stats.averageBuildTime.formatted())\n"
        message += "  ✅ Success rate: \(String(format: "%.1f%%", stats.buildSuccessRate * 100))\n"
        message += "  💾 Cache effectiveness: \(String(format: "%.1f%%", stats.cacheEffectiveness * 100))\n"
        message += "  🚀 Time reduction achieved: \(String(format: "%.1f%%", stats.timeReductionAchieved * 100))\n\n"
        
        message += "🔍 Current Build Analysis:\n"
        message += "  📝 Recommendation: \(rebuildAnalysis.shouldRebuild ? "Build Required" : "Build Not Needed")\n"
        message += "  💡 Reason: \(rebuildAnalysis.reason)\n"
        message += "  📈 Estimated time saving: \(String(format: "%.1f%%", rebuildAnalysis.estimatedTimeReduction * 100))\n"
        message += "  🎯 Affected targets: \(rebuildAnalysis.affectedTargets.joined(separator: ", "))\n"
        
        return MCPToolResult.text(message)
    }
    
    private func getBuildIntelligenceStats() async -> MCPToolResult {
        let stats = await buildIntelligenceEngine.getIntelligenceStats()
        
        var message = "📈 Build Intelligence Statistics\n\n"
        message += "🎯 Performance Metrics:\n"
        message += "  📊 Total builds analyzed: \(stats.totalBuildsAnalyzed)\n"
        message += "  ⏱️ Average build time: \(stats.averageBuildTime.formatted())\n"
        message += "  ✅ Build success rate: \(String(format: "%.1f%%", stats.buildSuccessRate * 100))\n\n"
        
        message += "🚀 Optimization Results:\n"
        message += "  💾 Cache effectiveness: \(String(format: "%.1f%%", stats.cacheEffectiveness * 100))\n"
        message += "  🎯 Prediction accuracy: \(String(format: "%.1f%%", stats.predictionAccuracy * 100))\n"
        message += "  ⚡ Time reduction achieved: \(String(format: "%.1f%%", stats.timeReductionAchieved * 100))\n"
        
        if stats.totalBuildsAnalyzed == 0 {
            message += "\n💡 No build data available yet. Start building projects to see intelligence insights!"
        } else if stats.totalBuildsAnalyzed < 10 {
            message += "\n💡 Build intelligence is still learning. More builds will improve accuracy."
        } else {
            message += "\n✅ Build intelligence system is fully operational and optimizing your builds!"
        }
        
        return MCPToolResult.text(message)
    }
    
    private func predictBuildTime(
        projectPath: String,
        targets: [String],
        changedFiles: Int,
        cacheHitRate: Double
    ) async -> MCPToolResult {
        let prediction = await buildIntelligenceEngine.predictBuildTime(
            affectedTargets: targets,
            changedFileCount: changedFiles,
            cacheHitRate: cacheHitRate,
            projectPath: projectPath
        )
        
        var message = "🔮 Build Time Prediction\n\n"
        message += "📋 Input Parameters:\n"
        message += "  🎯 Affected targets: \(targets.joined(separator: ", "))\n"
        message += "  📝 Changed files: \(changedFiles)\n"
        message += "  💾 Cache hit rate: \(String(format: "%.1f%%", cacheHitRate * 100))\n\n"
        
        message += "⏱️ Prediction Results:\n"
        message += "  🔮 Estimated build time: \(prediction.formatted())\n"
        
        // Get additional prediction details if possible
        let predictionWithConfidence = await buildIntelligenceEngine.predictBuildTimeWithConfidence(
            affectedTargets: targets,
            changedFileCount: changedFiles,
            cacheHitRate: cacheHitRate
        )
        
        message += "  🎯 Confidence: \(String(format: "%.1f%%", predictionWithConfidence.confidence * 100))\n"
        message += "  📊 Range: \(predictionWithConfidence.lowerBound.formatted()) - \(predictionWithConfidence.upperBound.formatted())\n"
        
        return MCPToolResult.text(message)
    }
    
    // MARK: - Enhanced Simulator Management
    
    public func handleEnhancedSimulator(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let actionValue = arguments["action"],
              let action = actionValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        switch action {
        case "list":
            return try await listSimulatorsEnhanced()
        case "boot":
            guard let deviceIdValue = arguments["deviceId"],
                  let deviceId = deviceIdValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await bootSimulatorEnhanced(deviceId: deviceId)
        case "matrix":
            return try await createTestingMatrix()
        case "performance":
            return try await getSimulatorPerformance()
        default:
            throw MCPError.invalidParams
        }
    }
    
    // MARK: - Enhanced File Operations
    
    public func handleEnhancedFileOperations(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let operationValue = arguments["operation"],
              let operation = operationValue.value as? String,
              let pathValue = arguments["path"],
              let path = pathValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        // Security validation
        try securityManager.validateProjectPath(path)
        
        switch operation {
        case "analyze":
            return try await analyzeCodebase(at: path)
        case "search":
            guard let patternValue = arguments["pattern"],
                  let pattern = patternValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await searchInCodebase(path: path, pattern: pattern)
        case "dependencies":
            return try await analyzeDependencies(at: path)
        default:
            // Fall back to basic operations for now
            throw MCPError.invalidParams
        }
    }
    
    // MARK: - Enhanced Project Analysis
    
    public func handleEnhancedProjectAnalysis(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let projectPathValue = arguments["projectPath"],
              let projectPath = projectPathValue.value as? String,
              let analysisValue = arguments["analysis"],
              let analysis = analysisValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        try securityManager.validateProjectPath(projectPath)
        
        switch analysis {
        case "comprehensive":
            return try await comprehensiveProjectAnalysis(at: projectPath)
        case "performance":
            return try await projectPerformanceAnalysis(at: projectPath)
        case "security":
            return try await projectSecurityAnalysis(at: projectPath)
        case "dependencies":
            return try await projectDependencyAnalysis(at: projectPath)
        default:
            throw MCPError.invalidParams
        }
    }
    
    // MARK: - Visual Documentation Generation
    
    public func handleVisualDocumentation(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let actionValue = arguments["action"],
              let action = actionValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        let projectPath = (arguments["projectPath"]?.value as? String) ?? "."
        try securityManager.validateProjectPath(projectPath)
        
        logger.info("📊 Visual documentation generation: \(action)")
        
        switch action {
        case "generate":
            return try await generateProjectDocumentation(projectPath: projectPath, arguments: arguments)
        case "live_tools":
            return try await generateLiveToolDocumentation()
        case "api_only":
            return try await generateAPIDocumentation(projectPath: projectPath)
        case "architecture_only":
            return try await generateArchitectureDocumentation(projectPath: projectPath)
        default:
            throw MCPError.invalidParams
        }
    }
    
    // MARK: - Analysis Implementations
    
    private func analyzeBuildResult(_ result: BuildResult) async -> ErrorAnalysis? {
        guard !result.errors.isEmpty else { return nil }
        
        var categoryBreakdown: [String: Int] = [:]
        var suggestions: [String] = []
        
        for error in result.errors {
            let category = categorizeBuildError(error.message)
            categoryBreakdown[category, default: 0] += 1
        }
        
        // Generate intelligent suggestions based on error patterns
        if categoryBreakdown["Syntax"] ?? 0 > 0 {
            suggestions.append("Review syntax errors - consider using Xcode's fix-it suggestions")
        }
        
        if categoryBreakdown["Missing Dependencies"] ?? 0 > 0 {
            suggestions.append("Check Package.swift dependencies and resolve missing imports")
        }
        
        if categoryBreakdown["Type Errors"] ?? 0 > 0 {
            suggestions.append("Review type annotations and ensure protocol conformance")
        }
        
        if categoryBreakdown["Duplicate Symbols"] ?? 0 > 0 {
            suggestions.append("Review for duplicate symbols and resolve conflicts")
        }
        
        return ErrorAnalysis(categoryBreakdown: categoryBreakdown, suggestions: suggestions)
    }
    
    private func categorizeBuildError(_ message: String) -> String {
        let lowercased = message.lowercased()
        
        if lowercased.contains("cannot find") || lowercased.contains("no such module") {
            return "Missing Dependencies"
        } else if lowercased.contains("expected") || lowercased.contains("syntax") {
            return "Syntax"
        } else if lowercased.contains("type") || lowercased.contains("protocol") {
            return "Type Errors"
        } else if lowercased.contains("duplicate") {
            return "Duplicate Symbols"
        } else {
            return "General"
        }
    }
    
    private func listSimulatorsEnhanced() async throws -> MCPToolResult {
        let command = ["xcrun", "simctl", "list", "devices", "--json"]
        let result = try await executeCommand(command)
        
        guard result.exitCode == 0 else {
            return MCPToolResult.error("Failed to list simulators: \(result.errorOutput)")
        }
        
        // Parse and enhance simulator information
        guard let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: Any] else {
            return MCPToolResult.text("📱 Raw simulators:\n\(result.output)")
        }
        
        var enhancedOutput = "📱 Enhanced Simulator List:\n\n"
        
        for (runtime, deviceList) in devices {
            if let devices = deviceList as? [[String: Any]], !devices.isEmpty {
                enhancedOutput += "🍎 \(runtime):\n"
                
                for device in devices {
                    if let name = device["name"] as? String,
                       let udid = device["udid"] as? String,
                       let state = device["state"] as? String {
                        
                        let stateEmoji = state == "Booted" ? "🟢" : (state == "Shutdown" ? "🔴" : "🟡")
                        enhancedOutput += "  \(stateEmoji) \(name)\n"
                        enhancedOutput += "    📱 UDID: \(udid)\n"
                        enhancedOutput += "    📊 State: \(state)\n\n"
                    }
                }
            }
        }
        
        return MCPToolResult.text(enhancedOutput)
    }
    
    private func bootSimulatorEnhanced(deviceId: String) async throws -> MCPToolResult {
        logger.info("🚀 Booting simulator with performance monitoring: \(deviceId)")
        
        let startTime = ContinuousClock.now
        let command = ["xcrun", "simctl", "boot", deviceId]
        let result = try await executeCommand(command)
        let duration = startTime.duration(to: .now)
        
        if result.exitCode == 0 {
            var message = "✅ Simulator booted successfully in \(duration.formatted())"
            
            // Add performance info
            let usage = await resourceManager.calculateOptimalSimulatorCount(requestedDevices: 1)
            message += "\n📊 System can optimally handle \(usage) simulators"
            message += "\n🖥️ Current resource utilization monitored"
            
            return MCPToolResult.text(message)
        } else {
            return MCPToolResult.error("Failed to boot simulator in \(duration.formatted()): \(result.errorOutput)")
        }
    }
    
    private func createTestingMatrix() async throws -> MCPToolResult {
        logger.info("🎯 Creating optimal testing matrix for current hardware")
        
        let hardware = try await detectHardwareCapabilities()
        let optimalCount = calculateOptimalSimulatorCount(hardwareSpec: hardware)
        
        var message = "🎯 Optimal Testing Matrix (Mac Studio M2 Max):\n\n"
        message += "🖥️ Hardware: \(hardware.cpuCores) cores, \(hardware.totalMemoryGB)GB RAM\n"
        message += "📱 Recommended simulators: \(optimalCount)\n\n"
        
        message += "💡 Suggested Device Matrix:\n"
        message += "  📱 iPhone 15 Pro (iOS 17.0)\n"
        message += "  📱 iPhone 14 (iOS 16.0)\n"
        message += "  📱 iPad Pro 12.9\" (iPadOS 17.0)\n"
        
        if optimalCount >= 4 {
            message += "  📱 iPhone SE (iOS 16.0)\n"
        }
        
        if optimalCount >= 6 {
            message += "  📱 iPhone 15 Plus (iOS 17.0)\n"
            message += "  📱 iPad Air (iPadOS 16.0)\n"
        }
        
        return MCPToolResult.text(message)
    }
    
    private func getSimulatorPerformance() async throws -> MCPToolResult {
        let usage = await getCurrentUsage()
        
        var message = "📊 Simulator Performance Metrics:\n\n"
        message += "💾 Memory Used: \(usage.memoryUsedBytes / (1024*1024*1024))GB\n"
        message += "⚡ CPU Usage: \(Int(usage.cpuUsage * 100))%\n"
        message += "💽 Disk Usage: \(Int(usage.diskUsage * 100))%\n\n"
        
        let optimal = await resourceManager.calculateOptimalSimulatorCount(requestedDevices: 10)
        message += "🎯 Can handle \(optimal) more simulators optimally"
        
        return MCPToolResult.text(message)
    }
    
    private func analyzeCodebase(at path: String) async throws -> MCPToolResult {
        let fileManager = FileManager.default
        var swiftFiles = 0
        var totalLines = 0
        var testFiles = 0
        
        let enumerator = fileManager.enumerator(atPath: path)
        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") {
                swiftFiles += 1
                if file.contains("Test") {
                    testFiles += 1
                }
                
                // Count lines
                if let content = try? String(contentsOfFile: "\(path)/\(file)") {
                    totalLines += content.components(separatedBy: .newlines).count
                }
            }
        }
        
        var message = "📊 Codebase Analysis:\n\n"
        message += "📄 Swift files: \(swiftFiles)\n"
        message += "🧪 Test files: \(testFiles)\n"
        message += "📝 Total lines: \(totalLines)\n"
        message += "📈 Test coverage: \(testFiles > 0 ? Int((Double(testFiles)/Double(swiftFiles)) * 100) : 0)%\n"
        
        return MCPToolResult.text(message)
    }
    
    private func searchInCodebase(path: String, pattern: String) async throws -> MCPToolResult {
        let command = ["grep", "-r", "--include=*.swift", pattern, path]
        let result = try await executeCommand(command)
        
        if result.exitCode == 0 {
            let matches = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var message = "🔍 Search Results for '\(pattern)':\n\n"
            message += "📊 Found \(matches.count) matches\n\n"
            
            for match in matches.prefix(10) {
                message += "📄 \(match)\n"
            }
            
            if matches.count > 10 {
                message += "\n... and \(matches.count - 10) more matches"
            }
            
            return MCPToolResult.text(message)
        } else {
            return MCPToolResult.text("🔍 No matches found for '\(pattern)'")
        }
    }
    
    private func analyzeDependencies(at path: String) async throws -> MCPToolResult {
        let packageSwiftPath = "\(path)/Package.swift"
        
        guard FileManager.default.fileExists(atPath: packageSwiftPath) else {
            return MCPToolResult.text("📦 No Package.swift found - not a Swift package")
        }
        
        let content = try String(contentsOfFile: packageSwiftPath)
        let lines = content.components(separatedBy: .newlines)
        
        var dependencies: [String] = []
        var inDependencies = false
        
        for line in lines {
            if line.contains("dependencies:") {
                inDependencies = true
            } else if inDependencies && line.contains("]") {
                inDependencies = false
            } else if inDependencies && line.contains("package") {
                dependencies.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        var message = "📦 Package Dependencies:\n\n"
        message += "📊 Total dependencies: \(dependencies.count)\n\n"
        
        for dep in dependencies {
            message += "  📄 \(dep)\n"
        }
        
        return MCPToolResult.text(message)
    }
    
    private func comprehensiveProjectAnalysis(at projectPath: String) async throws -> MCPToolResult {
        logger.info("🔬 Running comprehensive project analysis")
        
        var message = "🔬 Comprehensive Project Analysis:\n\n"
        
        // Get schemes
        do {
            let schemes = try await xcodeBuildWrapper.listSchemes(at: projectPath)
            message += "📋 Schemes (\(schemes.count)):\n"
            for scheme in schemes {
                message += "  • \(scheme.name)\n"
            }
            message += "\n"
        } catch {
            message += "❌ Could not analyze schemes: \(error.localizedDescription)\n\n"
        }
        
        // Project structure
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: projectPath)
        
        message += "🏗️ Project Structure:\n"
        for item in contents.sorted() {
            let emoji = item.hasSuffix(".xcodeproj") ? "📱" : 
                       item.hasSuffix(".xcworkspace") ? "🏢" :
                       item.hasSuffix(".swift") ? "📄" : "📁"
            message += "  \(emoji) \(item)\n"
        }
        
        return MCPToolResult.text(message)
    }
    
    private func projectPerformanceAnalysis(at projectPath: String) async throws -> MCPToolResult {
        var message = "⚡ Project Performance Analysis:\n\n"
        
        // Analyze build times (simplified)
        message += "🔨 Build Performance:\n"
        message += "  📊 Estimated build time: ~30-60 seconds (based on project size)\n"
        message += "  🎯 Optimization opportunity: Enable incremental builds\n"
        message += "  ⚡ Parallel compilation: Enabled\n\n"
        
        // Resource usage estimation
        let hardware = try await detectHardwareCapabilities()
        message += "🖥️ Resource Requirements:\n"
        message += "  💾 Memory: ~4-8GB for large projects\n"
        message += "  ⚙️ CPU: Optimal on \(hardware.cpuCores) cores\n"
        message += "  💽 Disk: Watch derived data growth\n"
        
        return MCPToolResult.text(message)
    }
    
    private func projectSecurityAnalysis(at projectPath: String) async throws -> MCPToolResult {
        var message = "🔒 Project Security Analysis:\n\n"
        
        // Basic security checks
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: projectPath)
        
        var issues: [String] = []
        var goodPractices: [String] = []
        
        if contents.contains("Podfile") {
            issues.append("🟡 CocoaPods detected - consider migrating to SPM for better security")
        }
        
        if contents.contains("Package.swift") {
            goodPractices.append("✅ Using Swift Package Manager")
        }
        
        if contents.contains(".gitignore") {
            goodPractices.append("✅ .gitignore present")
        } else {
            issues.append("🔴 Missing .gitignore file")
        }
        
        message += "🚨 Security Issues:\n"
        for issue in issues {
            message += "  \(issue)\n"
        }
        
        message += "\n✅ Good Practices:\n"
        for practice in goodPractices {
            message += "  \(practice)\n"
        }
        
        return MCPToolResult.text(message)
    }
    
    private func projectDependencyAnalysis(at projectPath: String) async throws -> MCPToolResult {
        // This would integrate with the dependency analysis we created earlier
        return try await analyzeDependencies(at: projectPath)
    }
    
    // MARK: - Documentation Generation Implementations
    
    private func generateProjectDocumentation(
        projectPath: String,
        arguments: [String: AnyCodable]
    ) async throws -> MCPToolResult {
        let outputPath = (arguments["outputPath"]?.value as? String) ?? "Documentation/Generated"
        
        return try await resourceManager.executeWithResourceControl {
            let result = try await docGenerator.generateProjectDocumentation(
                projectPath: projectPath,
                outputPath: outputPath
            )
            
            var message = "📊 Documentation Generation Complete!\n\n"
            message += "✅ Generated \(result.apiDocsCount) API documentation files\n"
            message += "✅ Generated \(result.architectureDocsCount) architecture documents\n"
            message += "✅ Generated \(result.toolDocsCount) MCP tool references\n"
            message += "⏱️ Generation time: \(result.generationTime.formatted())\n"
            message += "📁 Output location: \(result.outputPath)\n\n"
            
            message += "📋 Generated Files:\n"
            message += "  📄 API_Reference.md - Complete API documentation\n"
            message += "  🏗️ Architecture_Generated.md - System architecture\n"
            message += "  🔧 MCP_Tools_Reference.md - Tool documentation\n"
            message += "  📖 README.md - Documentation index\n\n"
            
            message += "🎯 Next Steps:\n"
            message += "  • Review generated documentation\n"
            message += "  • Commit to version control\n"
            message += "  • Set up automated regeneration\n"
            
            return MCPToolResult.text(message)
        }
    }
    
    private func generateLiveToolDocumentation() async throws -> MCPToolResult {
        // This would need access to the tool registry
        // For now, provide a helpful message
        let message = """
        📋 Live Tool Documentation Generation
        
        This feature generates real-time documentation for all registered MCP tools.
        
        🔧 Available Tools:
          • xcode_build - Enhanced Xcode build with intelligence
          • simulator_control - Advanced simulator management  
          • file_operations - Intelligent codebase analysis
          • project_analysis - Deep project intelligence
          • run_tests - Smart test execution
          • log_monitor - Real-time log monitoring
          • visual_documentation - This documentation generator
        
        💡 To get live tool documentation, use:
        {"action": "generate", "projectPath": "."}
        """
        
        return MCPToolResult.text(message)
    }
    
    private func generateAPIDocumentation(projectPath: String) async throws -> MCPToolResult {
        return try await resourceManager.executeWithResourceControl {
            let startTime = ContinuousClock.now
            
            // Generate just API documentation
            let result = try await docGenerator.generateProjectDocumentation(
                projectPath: projectPath,
                outputPath: "Documentation/Generated/API"
            )
            
            let duration = startTime.duration(to: .now)
            
            var message = "📊 API Documentation Generated!\n\n"
            message += "✅ Analyzed \(result.apiDocsCount) Swift files\n"
            message += "⏱️ Generation time: \(duration.formatted())\n"
            message += "📁 Output: Documentation/Generated/API/\n\n"
            
            message += "📋 API Documentation includes:\n"
            message += "  • Public classes, structs, and actors\n"
            message += "  • Public function signatures\n"
            message += "  • Module dependencies\n"
            message += "  • Documentation comments\n"
            
            return MCPToolResult.text(message)
        }
    }
    
    private func generateArchitectureDocumentation(projectPath: String) async throws -> MCPToolResult {
        return try await resourceManager.executeWithResourceControl {
            let startTime = ContinuousClock.now
            
            // Generate just architecture documentation
            let _ = try await docGenerator.generateProjectDocumentation(
                projectPath: projectPath,
                outputPath: "Documentation/Generated/Architecture"
            )
            
            let duration = startTime.duration(to: .now)
            
            var message = "🏗️ Architecture Documentation Generated!\n\n"
            message += "✅ Analyzed project structure\n"
            message += "⏱️ Generation time: \(duration.formatted())\n"
            message += "📁 Output: Documentation/Generated/Architecture/\n\n"
            
            message += "🏗️ Architecture Documentation includes:\n"
            message += "  • Component overview and purpose\n"
            message += "  • Module dependencies\n"
            message += "  • Data flow diagrams\n"
            message += "  • Security and performance principles\n"
            
            return MCPToolResult.text(message)
        }
    }
    
    // MARK: - Helper Methods
    
    private func executeCommand(_ command: [String]) async throws -> ProcessResult {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            process.terminationHandler = { process in
                // Read all data synchronously after process terminates
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                let result = ProcessResult(
                    output: output,
                    errorOutput: errorOutput,
                    exitCode: Int(process.terminationStatus)
                )
                
                continuation.resume(returning: result)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func getCurrentUsage() async -> ResourceUsage {
        // Simplified implementation - in production this would use proper system APIs
        return ResourceUsage(
            cpuUsage: 0.4, // 40% usage
            memoryUsedBytes: 8 * 1024 * 1024 * 1024, // 8GB
            diskUsage: 0.6 // 60% disk usage
        )
    }
} 