import Foundation
import Logging

/// Registry for managing and executing MCP tools
public actor MCPToolRegistry {
    private let logger: Logger
    private var tools: [String: RegisteredTool] = [:]
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    /// Register a tool with the registry
    public func registerTool(_ tool: RegisteredTool) async {
        tools[tool.definition.name] = tool
        logger.info("Registered MCP tool: \(tool.definition.name)")
    }
    
    /// Get all registered tools
    public func getAllTools() async -> [MCPTool] {
        return Array(tools.values.map(\.definition))
    }
    
    /// Execute a tool by name with given arguments
    public func executeTool(name: String, arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        guard let registeredTool = tools[name] else {
            throw MCPError.methodNotFound
        }
        
        logger.info("Executing tool: \(name)")
        
        do {
            let result = try await registeredTool.handler(arguments)
            logger.debug("Tool \(name) completed successfully")
            return result
        } catch {
            logger.error("Tool \(name) failed: \(error)")
            throw error
        }
    }
}

/// A registered tool with its definition and execution handler
public struct RegisteredTool {
    public let definition: MCPTool
    public let handler: ([String: AnyCodable]) async throws -> MCPToolResult
    
    public init(definition: MCPTool, handler: @escaping ([String: AnyCodable]) async throws -> MCPToolResult) {
        self.definition = definition
        self.handler = handler
    }
}

// MARK: - Tool Builder Helper

/// Helper for building tool definitions with proper schemas
public struct MCPToolBuilder {
    
    /// Build a tool for Xcode build operations
    public static func buildTool() -> MCPTool {
        let properties: [String: MCPPropertySchema] = [
            "projectPath": MCPPropertySchema(
                type: "string",
                description: "Path to the Xcode project or workspace"
            ),
            "scheme": MCPPropertySchema(
                type: "string", 
                description: "Build scheme to use"
            ),
            "destination": MCPPropertySchema(
                type: "string",
                description: "Build destination (e.g., 'platform=iOS Simulator,name=iPhone 15')",
                default: AnyCodable("platform=iOS Simulator,name=iPhone 15")
            ),
            "configuration": MCPPropertySchema(
                type: "string",
                description: "Build configuration",
                enum: ["Debug", "Release"],
                default: AnyCodable("Debug")
            )
        ]
        
        let schema = MCPToolInputSchema(
            properties: properties,
            required: ["projectPath", "scheme"]
        )
        
        return MCPTool(
            name: "xcode_build",
            description: "Build an Xcode project using xcodebuild with intelligent optimization",
            inputSchema: schema
        )
    }
    
    /// Build a tool for simulator management
    public static func simulatorTool() -> MCPTool {
        let properties: [String: MCPPropertySchema] = [
            "action": MCPPropertySchema(
                type: "string",
                description: "Action to perform",
                enum: ["list", "boot", "shutdown", "install", "launch", "screenshot"]
            ),
            "deviceId": MCPPropertySchema(
                type: "string",
                description: "Simulator device ID (optional for list action)"
            ),
            "appPath": MCPPropertySchema(
                type: "string",
                description: "Path to app bundle for install/launch actions"
            )
        ]
        
        let schema = MCPToolInputSchema(
            properties: properties,
            required: ["action"]
        )
        
        return MCPTool(
            name: "simulator_control",
            description: "Control iOS simulators: list, boot, shutdown, install apps, take screenshots",
            inputSchema: schema
        )
    }
    
    /// Build a tool for file operations
    public static func fileOperationTool() -> MCPTool {
        let properties: [String: MCPPropertySchema] = [
            "operation": MCPPropertySchema(
                type: "string",
                description: "File operation to perform",
                enum: ["read", "write", "list", "search", "create", "delete"]
            ),
            "path": MCPPropertySchema(
                type: "string",
                description: "File or directory path"
            ),
            "content": MCPPropertySchema(
                type: "string",
                description: "Content for write operations"
            ),
            "pattern": MCPPropertySchema(
                type: "string",
                description: "Search pattern for search operations"
            ),
            "recursive": MCPPropertySchema(
                type: "boolean",
                description: "Recursive operation for directory operations",
                default: AnyCodable(false)
            )
        ]
        
        let schema = MCPToolInputSchema(
            properties: properties,
            required: ["operation", "path"]
        )
        
        return MCPTool(
            name: "file_operations",
            description: "Secure file operations with sandbox protection",
            inputSchema: schema
        )
    }
    
    /// Build a tool for project analysis
    public static func projectAnalysisTool() -> MCPTool {
        let properties: [String: MCPPropertySchema] = [
            "projectPath": MCPPropertySchema(
                type: "string",
                description: "Path to the Xcode project"
            ),
            "analysis": MCPPropertySchema(
                type: "string",
                description: "Type of analysis to perform",
                enum: ["structure", "dependencies", "build_settings", "schemes", "targets"]
            )
        ]
        
        let schema = MCPToolInputSchema(
            properties: properties,
            required: ["projectPath", "analysis"]
        )
        
        return MCPTool(
            name: "project_analysis",
            description: "Analyze Xcode project structure, dependencies, and configuration",
            inputSchema: schema
        )
    }
    
    /// Build a tool for test execution
    public static func testTool() -> MCPTool {
        let properties: [String: MCPPropertySchema] = [
            "projectPath": MCPPropertySchema(
                type: "string",
                description: "Path to the Xcode project"
            ),
            "scheme": MCPPropertySchema(
                type: "string",
                description: "Test scheme to run"
            ),
            "destination": MCPPropertySchema(
                type: "string",
                description: "Test destination",
                default: AnyCodable("platform=iOS Simulator,name=iPhone 15")
            ),
            "testSuite": MCPPropertySchema(
                type: "string",
                description: "Specific test suite to run (optional)"
            ),
            "testClass": MCPPropertySchema(
                type: "string",
                description: "Specific test class to run (optional)"
            )
        ]
        
        let schema = MCPToolInputSchema(
            properties: properties,
            required: ["projectPath", "scheme"]
        )
        
        return MCPTool(
            name: "run_tests",
            description: "Execute Xcode tests with detailed reporting and failure analysis",
            inputSchema: schema
        )
    }
    
    /// Build a tool for log monitoring
    public static func logMonitorTool() -> MCPTool {
        let properties: [String: MCPPropertySchema] = [
            "action": MCPPropertySchema(
                type: "string",
                description: "Log monitoring action",
                enum: ["start", "stop", "tail", "query"]
            ),
            "deviceId": MCPPropertySchema(
                type: "string",
                description: "Simulator or device ID"
            ),
            "filterPredicate": MCPPropertySchema(
                type: "string",
                description: "NSPredicate string for filtering logs"
            ),
            "level": MCPPropertySchema(
                type: "string",
                description: "Log level filter",
                enum: ["debug", "info", "notice", "error", "fault"],
                default: AnyCodable("info")
            )
        ]
        
        let schema = MCPToolInputSchema(
            properties: properties,
            required: ["action"]
        )
        
        return MCPTool(
            name: "log_monitor",
            description: "Monitor and analyze iOS simulator and device logs in real-time",
            inputSchema: schema
        )
    }
}
