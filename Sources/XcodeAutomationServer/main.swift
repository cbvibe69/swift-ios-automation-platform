import Foundation
import ArgumentParser
import Logging
import SwiftMCP
import AutomationCore

/// Swift iOS Development Automation Platform
/// High-performance MCP server for Xcode automation with hybrid architecture
@main
struct XcodeAutomationPlatform: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcode-automation-server",
        abstract: "Swift iOS Development Automation Platform - MCP Server",
        version: "1.0.0"
    )
    
    @Option(help: "Log level (trace, debug, info, notice, warning, error, critical)")
    var logLevel: String = "info"
    
    @Option(help: "Server transport mode")
    var transport: TransportMode = .stdio
    
    @Option(help: "Maximum resource utilization percentage (70-95)")
    var maxResourceUtilization: Int = 85
    
    @Flag(help: "Enable development mode with additional debugging")
    var developmentMode: Bool = false
    
    @Flag(help: "Enable maximum security mode")
    var maximumSecurity: Bool = true
    
    enum TransportMode: String, CaseIterable, ExpressibleByArgument {
        case stdio
        case tcp
    }
    
    func run() async throws {
        // Configure logging
        let logLevel = Logger.Level(rawValue: self.logLevel) ?? .info
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        
        let logger = Logger(label: "xcode-automation-platform")
        logger.logLevel = logLevel
        
        logger.info("🚀 Starting Swift iOS Development Automation Platform")
        logger.info("Hardware: Mac Studio M2 Max optimization enabled")
        logger.info("Security: \(maximumSecurity ? "Maximum" : "Standard") mode")
        logger.info("Resource limit: \(maxResourceUtilization)%")
        
        // Initialize hardware optimization
        let hardwareSpec = try await detectHardwareCapabilities()
        logger.info("Detected: \(hardwareSpec.description)")
        
        // Create server configuration
        let config = ServerConfiguration(
            maxResourceUtilization: maxResourceUtilization,
            developmentMode: developmentMode,
            maximumSecurity: maximumSecurity,
            hardwareSpec: hardwareSpec,
            logger: logger
        )
        
        // Initialize MCP server with hybrid architecture
        let mcpServer = try await XcodeAutomationMCPServer(configuration: config)
        
        // Start server based on transport mode
        switch transport {
        case .stdio:
            logger.info("🔗 Starting MCP server with stdio transport (maximum security)")
            try await mcpServer.startStdioTransport()
        case .tcp:
            logger.info("🌐 Starting MCP server with TCP transport (localhost only)")
            try await mcpServer.startTCPTransport(port: 3333)
        }
    }
}

