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

/// Hardware capability detection for Mac Studio M2 Max optimization
func detectHardwareCapabilities() async throws -> HardwareSpec {
    let processInfo = ProcessInfo.processInfo
    
    // Get system information
    let physicalMemory = processInfo.physicalMemory
    let processorCount = processInfo.processorCount
    
    // Detect if this is Mac Studio M2 Max (or similar Apple Silicon)
    let isAppleSilicon = await detectAppleSilicon()
    let isM2Max = await detectM2MaxSpecifically()
    
    return HardwareSpec(
        totalMemoryGB: Int(physicalMemory / (1024 * 1024 * 1024)),
        cpuCores: processorCount,
        isAppleSilicon: isAppleSilicon,
        isM2Max: isM2Max,
        recommendedSimulators: calculateOptimalSimulatorCount(
            memoryGB: Int(physicalMemory / (1024 * 1024 * 1024)),
            cores: processorCount
        )
    )
}

func detectAppleSilicon() async -> Bool {
    // Check if running on Apple Silicon
    #if arch(arm64)
    return true
    #else
    return false
    #endif
}

func detectM2MaxSpecifically() async -> Bool {
    // This would require more specific hardware detection
    // For now, assume M2 Max if we have 32GB+ RAM and 10+ cores on Apple Silicon
    let processInfo = ProcessInfo.processInfo
    let memoryGB = Int(processInfo.physicalMemory / (1024 * 1024 * 1024))
    let cores = processInfo.processorCount
    
    return await detectAppleSilicon() && memoryGB >= 32 && cores >= 10
}

func calculateOptimalSimulatorCount(memoryGB: Int, cores: Int) -> Int {
    // Conservative calculation: 2GB per simulator, leave 8GB for system
    let availableMemory = memoryGB - 8
    let memoryBasedLimit = max(1, availableMemory / 2)
    
    // CPU-based limit: assume 1-2 simulators per core
    let cpuBasedLimit = cores * 2
    
    // Return the more conservative estimate
    return min(memoryBasedLimit, cpuBasedLimit, 12) // Cap at 12 simulators
}