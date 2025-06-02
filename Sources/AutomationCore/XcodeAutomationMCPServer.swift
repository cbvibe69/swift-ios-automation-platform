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
        
        // Register all MCP tools
        try await registerTools()
        
        logger.info("✅ MCP Server initialized successfully")
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
            guard let line = readLine(strippingNewline: true), !line.isEmpty else {
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
                await sendErrorResponse(id: nil, error: MCPError.parseError)
                return
            }
            
            let decoder = JSONDecoder()
            let request = try decoder.decode(MCPRequest.self, from: data)
            
            // Process request through protocol handler
            let response = await protocolHandler.processRequest(request)
            
            // Send response back via stdout
            await sendResponse(response)
            
        } catch {
            logger.error("Failed to process message: \(error)")
            await sendErrorResponse(id: nil, error: MCPError.parseError)
        }
    }
    
    private func sendResponse(_ response: MCPResponse) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
                fflush(stdout)
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
            return try await listSimulators()
        case "boot":
            guard let deviceIdValue = arguments["deviceId"],
                  let deviceId = deviceIdValue.value as? String else {
                throw MCPError.invalidParams
            }
            return try await bootSimulator(deviceId: deviceId)
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
    
    // MARK: - Implementation Helpers
    
    private func listSimulators() async throws -> MCPToolResult {
        let command = ["xcrun", "simctl", "list", "devices", "--json"]
        let result = try await executeCommand(command)
        
        if result.exitCode == 0 {
            return MCPToolResult.text("📱 Simulators:\n\(result.output)")
        } else {
            return MCPToolResult.error("Failed to list simulators: \(result.errorOutput)")
        }
    }
    
    private func bootSimulator(deviceId: String) async throws -> MCPToolResult {
        let command = ["xcrun", "simctl", "boot", deviceId]
        let result = try await executeCommand(command)
        
        if result.exitCode == 0 {
            return MCPToolResult.text("✅ Simulator \(deviceId) booted successfully")
        } else {
            return MCPToolResult.error("Failed to boot simulator: \(result.errorOutput)")
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