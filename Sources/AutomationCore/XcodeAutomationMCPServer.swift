import Foundation
import SwiftMCP
import Logging
import Subprocess
import ConcurrencyExtras
import SystemPackage

/// Core MCP Server for Xcode automation with modern Swift architecture
public final class XcodeAutomationMCPServer {
    
    // MARK: - Core Components
    private let logger: Logger
    private let protocolHandler: MCPProtocolHandler
    private let toolRegistry: MCPToolRegistry
    private let xcodeBuildWrapper: XcodeBuildWrapper
    private let configuration: ServerConfiguration
    private let enhancedToolHandlers: EnhancedToolHandlers
    private let simulatorManager: SimulatorManager
    
    // MARK: - State Management
    private var isRunning = false
    private var activeProjects: Set<String> = []
    
    public init(configuration: ServerConfiguration) async throws {
        self.configuration = configuration
        self.logger = configuration.logger
        
        logger.info("🏗️ Initializing Swift iOS Automation Platform")
        
        // Initialize core components
        self.toolRegistry = MCPToolRegistry(logger: logger)
        self.protocolHandler = MCPProtocolHandler(logger: logger, toolRegistry: toolRegistry)
        self.xcodeBuildWrapper = XcodeBuildWrapper(logger: logger)
        
        // Initialize enhanced components for Phase 2
        let hardwareSpec = HardwareSpec(
            cpuCores: HardwareDetection.cpuCoreCount(),
            totalMemoryGB: Int(HardwareDetection.memorySize() / (1024 * 1024 * 1024)),
            architecture: HardwareDetection.architecture()
        )
        
        let resourceManager = try await ResourceManager(
            hardwareSpec: hardwareSpec,
            maxUtilization: configuration.maxResourceUtilization,
            logger: logger
        )
        let securityManager = SecurityManager()
        
        // Initialize Simulator Manager (Task 07 completion)
        self.simulatorManager = SimulatorManager(
            logger: logger,
            resourceManager: resourceManager,
            maxConcurrentDevices: hardwareSpec.cpuCores > 8 ? 8 : 6
        )
        
        self.enhancedToolHandlers = EnhancedToolHandlers(
            logger: logger,
            xcodeBuildWrapper: xcodeBuildWrapper,
            resourceManager: resourceManager,
            securityManager: securityManager
        )
        
        // Register all MCP tools
        try await registerTools()
        
        logger.info("✅ Swift iOS Automation Platform initialized successfully")
        logger.info("🖥️ Hardware: \(hardwareSpec.cpuCores) cores, \(hardwareSpec.totalMemoryGB)GB RAM, \(hardwareSpec.architecture)")
        logger.info("📱 Max concurrent simulators: \(hardwareSpec.cpuCores > 8 ? 8 : 6)")
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the MCP server with stdio transport (recommended for security)
    public func startStdioTransport() async throws {
        logger.info("📡 Starting MCP server with stdio transport (zero network exposure)")
        isRunning = true
        
        try await runStdioMessageLoop()
    }
    
    /// Start the MCP server with TCP transport (localhost only)
    public func startTCPTransport(port: Int = 8080) async throws {
        logger.info("🌐 Starting MCP server with TCP transport on localhost:\(port)")
        isRunning = true
        
        // TCP implementation would go here
        // For now, we'll focus on stdio transport as it's more secure
        throw MCPError.internalError
    }
    
    /// Stop the MCP server gracefully
    public func stop() async {
        logger.info("🛑 Stopping MCP server")
        isRunning = false
    }
    
    // MARK: - Message Processing
    
    private func runStdioMessageLoop() async throws {
        logger.debug("Starting stdio message loop")
        
        while isRunning {
            // Read a line from stdin
            guard let line = readLine(strippingNewline: true) else {
                // EOF received, exit gracefully
                logger.debug("EOF received, stopping message loop")
                break
            }
            
            // Skip empty lines
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Process the MCP request
            await processMessageLine(line)
        }
    }
    
    private func processMessageLine(_ line: String) async {
        do {
            // Parse JSON-RPC request
            guard let data = line.data(using: .utf8) else {
                logger.warning("Invalid UTF-8 in message: \(line)")
                await sendErrorResponse(id: nil, error: MCPError.parseError)
                return
            }
            
            let decoder = JSONDecoder()
            let request = try decoder.decode(MCPRequest.self, from: data)
            
            logger.debug("Processing request: \(request.method) with id: \(request.id)")
            
            // Process request through protocol handler
            let response = await protocolHandler.processRequest(request)
            
            // Send response back via stdout
            await sendResponse(response)
            
        } catch let decodingError as DecodingError {
            logger.error("JSON decode error: \(decodingError)")
            await sendErrorResponse(id: nil, error: MCPError.parseError)
        } catch {
            logger.error("Failed to process message: \(error)")
            await sendErrorResponse(id: nil, error: MCPError.internalError)
        }
    }
    
    private func sendResponse(_ response: MCPResponse) async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [] // Compact JSON without extra formatting
            let data = try encoder.encode(response)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
                FileHandle.standardOutput.synchronizeFile() // Swift's proper stdout flushing
            }
        } catch {
            logger.error("Failed to encode response: \(error)")
        }
    }
    
    private func sendErrorResponse(id: RequestID?, error: MCPError) async {
        let response = MCPResponse(id: id, error: error)
        await sendResponse(response)
    }
    
    // MARK: - Tool Registration
    
    private func registerTools() async throws {
        logger.info("🔧 Registering MCP tools")
        
        // Register Xcode build tool
        let buildTool = RegisteredTool(
            definition: MCPToolBuilder.buildTool(),
            handler: { [weak self] arguments in
                try await self?.handleBuildTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(buildTool)
        
        // Register simulator control tool
        let simulatorTool = RegisteredTool(
            definition: MCPToolBuilder.simulatorTool(),
            handler: { [weak self] arguments in
                try await self?.handleSimulatorTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(simulatorTool)
        
        // Register file operations tool
        let fileTool = RegisteredTool(
            definition: MCPToolBuilder.fileOperationTool(),
            handler: { [weak self] arguments in
                try await self?.handleFileOperationTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(fileTool)
        
        // Register project analysis tool
        let analysisTool = RegisteredTool(
            definition: MCPToolBuilder.projectAnalysisTool(),
            handler: { [weak self] arguments in
                try await self?.handleProjectAnalysisTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(analysisTool)
        
        // Register test execution tool
        let testTool = RegisteredTool(
            definition: MCPToolBuilder.testTool(),
            handler: { [weak self] arguments in
                try await self?.handleTestTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(testTool)
        
        // Register log monitoring tool
        let logTool = RegisteredTool(
            definition: MCPToolBuilder.logMonitorTool(),
            handler: { [weak self] arguments in
                try await self?.handleLogMonitorTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(logTool)
        
        // Register visual documentation tool
        let visualDocTool = RegisteredTool(
            definition: MCPToolBuilder.visualDocumentationTool(),
            handler: { [weak self] arguments in
                try await self?.handleVisualDocumentationTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(visualDocTool)
        
        // Register Build Intelligence tool
        let buildIntelligenceTool = RegisteredTool(
            definition: MCPToolBuilder.buildIntelligenceTool(),
            handler: { [weak self] arguments in
                try await self?.handleBuildIntelligenceTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(buildIntelligenceTool)
        
        // Register Enhanced Build tool
        let enhancedBuildTool = RegisteredTool(
            definition: MCPToolBuilder.enhancedBuildTool(),
            handler: { [weak self] arguments in
                try await self?.handleEnhancedBuildTool(arguments: arguments) ?? MCPToolResult.error("Server unavailable")
            }
        )
        await toolRegistry.registerTool(enhancedBuildTool)
        
        logger.info("✅ All MCP tools registered successfully")
    }
    
    // MARK: - Tool Handlers
    
    private func handleBuildTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let projectPathValue = arguments["projectPath"],
              let projectPath = projectPathValue.value as? String,
              let schemeValue = arguments["scheme"],
              let scheme = schemeValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        let destination = (arguments["destination"]?.value as? String) ?? "platform=iOS Simulator,name=iPhone 15"
        let configurationString = (arguments["configuration"]?.value as? String) ?? "Debug"
        let configuration = BuildConfiguration(rawValue: configurationString) ?? .debug
        
        logger.info("🔨 Building project: \(projectPath) scheme: \(scheme)")
        
        do {
            let result = try await xcodeBuildWrapper.buildProject(
                at: projectPath,
                scheme: scheme,
                destination: destination,
                configuration: configuration
            )
            
            if result.success {
                var message = "✅ Build succeeded in \(result.duration.formatted())"
                if !result.warnings.isEmpty {
                    message += "\n⚠️ Warnings: \(result.warnings.count)"
                }
                return MCPToolResult.text(message)
            } else {
                var message = "❌ Build failed in \(result.duration.formatted())"
                if !result.errors.isEmpty {
                    message += "\n🚨 Errors: \(result.errors.count)"
                    for error in result.errors.prefix(3) {
                        message += "\n  • \(error.message)"
                    }
                }
                return MCPToolResult.error(message)
            }
        } catch {
            logger.error("Build failed: \(error)")
            return MCPToolResult.error("Build failed: \(error.localizedDescription)")
        }
    }
    
    private func handleSimulatorTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
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
        case "shutdown":
            if let deviceIdValue = arguments["deviceId"],
               let deviceId = deviceIdValue.value as? String {
                return try await shutdownSimulatorEnhanced(deviceId: deviceId)
            } else {
                return try await shutdownAllSimulators()
            }
        case "matrix":
            return try await createTestingMatrix()
        case "status":
            return try await getSimulatorStatus()
        case "install":
            guard let deviceIdValue = arguments["deviceId"],
                  let deviceId = deviceIdValue.value as? String,
                  let appPathValue = arguments["appPath"],
                  let appPath = appPathValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await installAppOnSimulator(deviceId: deviceId, appPath: appPath)
        case "launch":
            guard let deviceIdValue = arguments["deviceId"],
                  let deviceId = deviceIdValue.value as? String,
                  let bundleIdValue = arguments["bundleId"],
                  let bundleId = bundleIdValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await launchAppOnSimulator(deviceId: deviceId, bundleId: bundleId)
        case "screenshot":
            let deviceId = (arguments["deviceId"]?.value as? String) ?? "booted"
            return try await takeSimulatorScreenshot(deviceId: deviceId)
        default:
            throw MCPError.invalidParams
        }
    }
    
    private func handleFileOperationTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let operationValue = arguments["operation"],
              let operation = operationValue.value as? String,
              let pathValue = arguments["path"],
              let path = pathValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        switch operation {
        case "read":
            return try await readFile(at: path)
        case "write":
            guard let contentValue = arguments["content"],
                  let content = contentValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await writeFile(at: path, content: content)
        case "list":
            return try await listDirectory(at: path)
        default:
            throw MCPError.invalidParams
        }
    }
    
    private func handleProjectAnalysisTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let projectPathValue = arguments["projectPath"],
              let projectPath = projectPathValue.value as? String,
              let analysisValue = arguments["analysis"],
              let analysis = analysisValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        switch analysis {
        case "schemes":
            return try await analyzeProjectSchemes(at: projectPath)
        case "structure":
            return try await analyzeProjectStructure(at: projectPath)
        default:
            throw MCPError.invalidParams
        }
    }
    
    private func handleTestTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let projectPathValue = arguments["projectPath"],
              let projectPath = projectPathValue.value as? String,
              let schemeValue = arguments["scheme"],
              let scheme = schemeValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        let destination = (arguments["destination"]?.value as? String) ?? "platform=iOS Simulator,name=iPhone 15"
        
        logger.info("🧪 Running tests: \(projectPath) scheme: \(scheme)")
        
        do {
            let result = try await xcodeBuildWrapper.runTests(
                at: projectPath,
                scheme: scheme,
                destination: destination
            )
            
            var message = result.success ? "✅ All tests passed" : "❌ Some tests failed"
            message += " in \(result.duration.formatted())"
            message += "\n📊 Results: \(result.passedCount) passed, \(result.failedCount) failed"
            
            if !result.testCases.isEmpty {
                let failedTests = result.testCases.filter { $0.status == .failed }
                if !failedTests.isEmpty {
                    message += "\n\n🚨 Failed tests:"
                    for test in failedTests.prefix(5) {
                        message += "\n  • \(test.name)"
                    }
                }
            }
            
            return MCPToolResult.text(message)
        } catch {
            logger.error("Test execution failed: \(error)")
            return MCPToolResult.error("Test execution failed: \(error.localizedDescription)")
        }
    }
    
    private func handleLogMonitorTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let actionValue = arguments["action"],
              let action = actionValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        // For now, return a placeholder implementation
        return MCPToolResult.text("Log monitoring not yet implemented for action: \(action)")
    }
    
    private func handleVisualDocumentationTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        // Delegate to the enhanced tool handlers for visual documentation
        return try await enhancedToolHandlers.handleVisualDocumentation(arguments: arguments)
    }
    
    private func handleBuildIntelligenceTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        // Delegate to the enhanced tool handlers for Build Intelligence
        return try await enhancedToolHandlers.handleBuildIntelligence(arguments: arguments)
    }
    
    private func handleEnhancedBuildTool(arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        // Delegate to the enhanced tool handlers for Enhanced Build
        return try await enhancedToolHandlers.handleEnhancedBuild(arguments: arguments)
    }
    
    // MARK: - Enhanced Simulator Operations (Task 07)
    
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
        
        // Get resource status for recommendations
        let resourceStatus = await simulatorManager.getResourceStatus()
        
        enhancedOutput += "🖥️ System Status:\n"
        enhancedOutput += "  • Current Active: \(resourceStatus.currentActiveDevices)\n"
        enhancedOutput += "  • Max Optimal: \(resourceStatus.maxOptimalDevices)\n"
        enhancedOutput += "  • Available Slots: \(resourceStatus.availableSlots)\n"
        enhancedOutput += "  • Memory Pressure: \(resourceStatus.memoryPressure ? "⚠️ HIGH" : "✅ Normal")\n\n"
        
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
        
        enhancedOutput += "💡 Recommendations:\n"
        for recommendation in resourceStatus.recommendations {
            enhancedOutput += "  • \(recommendation)\n"
        }
        
        return MCPToolResult.text(enhancedOutput)
    }
    
    private func bootSimulatorEnhanced(deviceId: String) async throws -> MCPToolResult {
        logger.info("🚀 Booting simulator with resource management: \(deviceId)")
        
        do {
            let results = try await simulatorManager.bootDevices([deviceId])
            let result = results.first!
            
            var message = "✅ Simulator booted successfully"
            if result.wasAlreadyBooted {
                message += " (was already booted)"
            } else {
                message += " in \(String(format: "%.2f", result.bootTime))s"
            }
            
            // Add resource info
            let resourceStatus = await simulatorManager.getResourceStatus()
            message += "\n📊 System can handle \(resourceStatus.availableSlots) more simulators"
            message += "\n🖥️ Current active devices: \(resourceStatus.currentActiveDevices)"
            
            return MCPToolResult.text(message)
            
        } catch {
            return MCPToolResult.error("Failed to boot simulator: \(error.localizedDescription)")
        }
    }
    
    private func shutdownSimulatorEnhanced(deviceId: String) async throws -> MCPToolResult {
        logger.info("🛑 Shutting down simulator: \(deviceId)")
        
        do {
            try await simulatorManager.shutdownDevices([deviceId])
            
            let resourceStatus = await simulatorManager.getResourceStatus()
            let message = "✅ Simulator shutdown successfully\n📊 Available slots: \(resourceStatus.availableSlots)"
            
            return MCPToolResult.text(message)
            
        } catch {
            return MCPToolResult.error("Failed to shutdown simulator: \(error.localizedDescription)")
        }
    }
    
    private func shutdownAllSimulators() async throws -> MCPToolResult {
        logger.info("🛑 Shutting down all managed simulators")
        
        do {
            try await simulatorManager.shutdownAll()
            return MCPToolResult.text("✅ All simulators shutdown and cleaned up")
            
        } catch {
            return MCPToolResult.error("Failed to shutdown simulators: \(error.localizedDescription)")
        }
    }
    
    private func createTestingMatrix() async throws -> MCPToolResult {
        logger.info("🎯 Creating optimal testing matrix")
        
        do {
            let matrix = try await simulatorManager.createTestingMatrix()
            
            var message = "🎯 Optimal Testing Matrix:\n\n"
            message += "🖥️ Selected Devices (\(matrix.selectedDevices.count)):\n"
            
            for device in matrix.selectedDevices {
                let stateEmoji = device.state == "Booted" ? "🟢" : "🔴"
                message += "  \(stateEmoji) \(device.name)\n"
                message += "    📱 UDID: \(device.udid)\n"
            }
            
            message += "\n📊 Performance:\n"
            message += "  • Optimal Concurrency: \(matrix.optimalConcurrency)\n"
            message += "  • Estimated Test Time: \(String(format: "%.1f", matrix.estimatedTestTime))s\n"
            message += "  • Device Types: \(matrix.deviceTypes.count) unique types\n"
            
            return MCPToolResult.text(message)
            
        } catch {
            return MCPToolResult.error("Failed to create testing matrix: \(error.localizedDescription)")
        }
    }
    
    private func getSimulatorStatus() async throws -> MCPToolResult {
        let resourceStatus = await simulatorManager.getResourceStatus()
        let managedDevices = await simulatorManager.getManagedDeviceStatus()
        
        var message = "📊 Simulator Manager Status:\n\n"
        
        message += "🖥️ Resource Status:\n"
        message += "  • Current Active: \(resourceStatus.currentActiveDevices)\n"
        message += "  • Max Optimal: \(resourceStatus.maxOptimalDevices)\n"
        message += "  • Available Slots: \(resourceStatus.availableSlots)\n"
        message += "  • Memory Pressure: \(resourceStatus.memoryPressure ? "⚠️ HIGH" : "✅ Normal")\n\n"
        
        if !managedDevices.isEmpty {
            message += "📱 Managed Devices (\(managedDevices.count)):\n"
            
            for (deviceId, device) in managedDevices {
                let stateEmoji = device.state == .booted ? "🟢" : (device.state == .booting ? "🟡" : "🔴")
                message += "  \(stateEmoji) \(deviceId.prefix(8))...\n"
                message += "    State: \(device.state)\n"
                message += "    Boot Time: \(device.bootTime.formatted(date: .omitted, time: .shortened))\n"
                message += "    Last Check: \(device.lastHealthCheck.formatted(date: .omitted, time: .shortened))\n\n"
            }
        }
        
        message += "💡 Recommendations:\n"
        for recommendation in resourceStatus.recommendations {
            message += "  • \(recommendation)\n"
        }
        
        return MCPToolResult.text(message)
    }
    
    private func installAppOnSimulator(deviceId: String, appPath: String) async throws -> MCPToolResult {
        logger.info("📲 Installing app on simulator: \(deviceId)")
        
        do {
            let results = try await simulatorManager.installAppOnDevices(appPath: appPath, deviceIds: [deviceId])
            
            if results[deviceId] == true {
                return MCPToolResult.text("✅ App installed successfully on simulator")
            } else {
                return MCPToolResult.error("Failed to install app on simulator")
            }
            
        } catch {
            return MCPToolResult.error("Failed to install app: \(error.localizedDescription)")
        }
    }
    
    private func launchAppOnSimulator(deviceId: String, bundleId: String) async throws -> MCPToolResult {
        logger.info("🚀 Launching app on simulator: \(bundleId)")
        
        do {
            let results = try await simulatorManager.launchAppOnDevices(bundleId: bundleId, deviceIds: [deviceId])
            
            if let pid = results[deviceId], pid > 0 {
                return MCPToolResult.text("✅ App launched successfully with PID: \(pid)")
            } else {
                return MCPToolResult.error("Failed to launch app on simulator")
            }
            
        } catch {
            return MCPToolResult.error("Failed to launch app: \(error.localizedDescription)")
        }
    }
    
    private func takeSimulatorScreenshot(deviceId: String) async throws -> MCPToolResult {
        let tempDir = FileManager.default.temporaryDirectory
        let screenshotPath = tempDir.appendingPathComponent("simulator_screenshot_\(Date().timeIntervalSince1970).png")
        
        let command = ["xcrun", "simctl", "io", deviceId, "screenshot", screenshotPath.path]
        let result = try await executeCommand(command)
        
        if result.exitCode == 0 {
            return MCPToolResult.text("📸 Screenshot saved to: \(screenshotPath.path)")
        } else {
            return MCPToolResult.error("Failed to take screenshot: \(result.errorOutput)")
        }
    }
    
    private func readFile(at path: String) async throws -> MCPToolResult {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return MCPToolResult.text("📄 File content:\n\(content)")
        } catch {
            return MCPToolResult.error("Failed to read file: \(error.localizedDescription)")
        }
    }
    
    private func writeFile(at path: String, content: String) async throws -> MCPToolResult {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return MCPToolResult.text("✅ File written successfully to: \(path)")
        } catch {
            return MCPToolResult.error("Failed to write file: \(error.localizedDescription)")
        }
    }
    
    private func listDirectory(at path: String) async throws -> MCPToolResult {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            let listing = contents.joined(separator: "\n")
            return MCPToolResult.text("📁 Directory contents:\n\(listing)")
        } catch {
            return MCPToolResult.error("Failed to list directory: \(error.localizedDescription)")
        }
    }
    
    private func analyzeProjectSchemes(at projectPath: String) async throws -> MCPToolResult {
        do {
            let schemes = try await xcodeBuildWrapper.listSchemes(at: projectPath)
            let schemeNames = schemes.map { $0.name }.joined(separator: "\n")
            return MCPToolResult.text("📋 Available schemes:\n\(schemeNames)")
        } catch {
            return MCPToolResult.error("Failed to analyze schemes: \(error.localizedDescription)")
        }
    }
    
    private func analyzeProjectStructure(at projectPath: String) async throws -> MCPToolResult {
        // Basic project structure analysis
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: projectPath)
            let structure = contents.joined(separator: "\n")
            return MCPToolResult.text("🏗️ Project structure:\n\(structure)")
        } catch {
            return MCPToolResult.error("Failed to analyze project structure: \(error.localizedDescription)")
        }
    }
    
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
}

// MARK: - Supporting Types

public struct ServerConfiguration {
    public let logger: Logger
    public let maxResourceUtilization: Int
    public let developmentMode: Bool
    
    public init(
        logger: Logger,
        maxResourceUtilization: Int = 80,
        developmentMode: Bool = true
    ) {
        self.logger = logger
        self.maxResourceUtilization = maxResourceUtilization
        self.developmentMode = developmentMode
    }
}