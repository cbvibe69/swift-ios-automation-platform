import Foundation
import Logging

// MARK: - MCP Protocol Core Types

/// JSON-RPC 2.0 Request as per MCP specification
public struct MCPRequest: Codable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: RequestID
    public let method: String
    public let params: [String: AnyCodable]?
    
    public init(id: RequestID, method: String, params: [String: AnyCodable]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 Response as per MCP specification
public struct MCPResponse: Codable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: RequestID?
    public let result: AnyCodable?
    public let error: MCPError?
    
    public init(id: RequestID?, result: AnyCodable? = nil, error: MCPError? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }
}

/// MCP Error following JSON-RPC 2.0 error format
public struct MCPError: Codable, Error, Sendable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?
    
    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
    
    // Standard JSON-RPC 2.0 error codes
    public static let parseError = MCPError(code: -32700, message: "Parse error")
    public static let invalidRequest = MCPError(code: -32600, message: "Invalid Request")
    public static let methodNotFound = MCPError(code: -32601, message: "Method not found")
    public static let invalidParams = MCPError(code: -32602, message: "Invalid params")
    public static let internalError = MCPError(code: -32603, message: "Internal error")
    
    // MCP-specific error codes
    public static func buildFailed(_ message: String) -> MCPError {
        MCPError(code: -32000, message: "Build failed: \(message)")
    }
    
    public static func securityViolation(_ message: String) -> MCPError {
        MCPError(code: -32001, message: "Security violation: \(message)")
    }
    
    public static func resourceExhausted(_ message: String) -> MCPError {
        MCPError(code: -32002, message: "Resource exhausted: \(message)")
    }
}

/// Request ID can be string, number, or null
public enum RequestID: Codable, Sendable, Hashable {
    case string(String)
    case number(Int)
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Int.self) {
            self = .number(number)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid request ID")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .null:
            try container.encodeNil()
        }
    }
}

/// Type-erased codable value for flexible parameter handling
public struct AnyCodable: Codable, Sendable {
    public let value: Any
    
    public init<T: Codable>(_ value: T) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            // Simple encoding for basic JSON arrays
            if let stringArray = array as? [String] {
                try container.encode(stringArray)
            } else if let intArray = array as? [Int] {
                try container.encode(intArray)
            } else if let boolArray = array as? [Bool] {
                try container.encode(boolArray)
            } else {
                // Fallback to empty array for unsupported complex arrays
                try container.encode([String]())
            }
        case let dictionary as [String: Any]:
            // Simple encoding for basic JSON dictionaries
            var simpleDictionary: [String: String] = [:]
            for (key, dictValue) in dictionary {
                if let stringValue = dictValue as? String {
                    simpleDictionary[key] = stringValue
                } else if let intValue = dictValue as? Int {
                    simpleDictionary[key] = String(intValue)
                } else if let boolValue = dictValue as? Bool {
                    simpleDictionary[key] = String(boolValue)
                } else {
                    simpleDictionary[key] = String(describing: dictValue)
                }
            }
            try container.encode(simpleDictionary)
        default:
            // Fallback to string representation
            try container.encode(String(describing: value))
        }
    }
}

// MARK: - MCP Server Capability Declaration

/// Server capabilities exposed via the initialize method
public struct MCPServerCapabilities: Codable, Sendable {
    public let tools: MCPToolsCapability?
    public let prompts: MCPPromptsCapability?
    public let resources: MCPResourcesCapability?
    public let logging: MCPLoggingCapability?
    
    public init(
        tools: MCPToolsCapability? = nil,
        prompts: MCPPromptsCapability? = nil,
        resources: MCPResourcesCapability? = nil,
        logging: MCPLoggingCapability? = nil
    ) {
        self.tools = tools
        self.prompts = prompts
        self.resources = resources
        self.logging = logging
    }
}

public struct MCPToolsCapability: Codable, Sendable {
    public let listChanged: Bool?
    
    public init(listChanged: Bool? = true) {
        self.listChanged = listChanged
    }
}

public struct MCPPromptsCapability: Codable, Sendable {
    public let listChanged: Bool?
    
    public init(listChanged: Bool? = true) {
        self.listChanged = listChanged
    }
}

public struct MCPResourcesCapability: Codable, Sendable {
    public let subscribe: Bool?
    public let listChanged: Bool?
    
    public init(subscribe: Bool? = true, listChanged: Bool? = true) {
        self.subscribe = subscribe
        self.listChanged = listChanged
    }
}

public struct MCPLoggingCapability: Codable, Sendable {
    public let level: String?
    
    public init(level: String? = "info") {
        self.level = level
    }
}

// MARK: - MCP Tools

/// Tool definition as per MCP specification
public struct MCPTool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: MCPToolInputSchema
    
    public init(name: String, description: String, inputSchema: MCPToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema for tool input parameters
public struct MCPToolInputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: MCPPropertySchema]
    public let required: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case type, properties, required
    }
    
    public init(properties: [String: MCPPropertySchema], required: [String]? = nil) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

/// JSON Schema property definition
public struct MCPPropertySchema: Codable, Sendable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let `default`: AnyCodable?
    
    public init(type: String, description: String? = nil, enum: [String]? = nil, default: AnyCodable? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self.default = `default`
    }
}

/// Tool execution result
public struct MCPToolResult: Codable, Sendable {
    public let content: [MCPContent]
    public let isError: Bool?
    
    public init(content: [MCPContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }
    
    public static func text(_ text: String) -> MCPToolResult {
        MCPToolResult(content: [MCPContent.text(text)])
    }
    
    public static func error(_ message: String) -> MCPToolResult {
        MCPToolResult(content: [MCPContent.text(message)], isError: true)
    }
}

/// Content types for tool results
public enum MCPContent: Codable, Sendable {
    case text(String)
    case image(MCPImageContent)
    case resource(MCPResourceContent)
    
    private enum CodingKeys: String, CodingKey {
        case type, text, data, mimeType, uri
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            self = .image(MCPImageContent(data: data, mimeType: mimeType))
        case "resource":
            let uri = try container.decode(String.self, forKey: .uri)
            let mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
            self = .resource(MCPResourceContent(uri: uri, mimeType: mimeType))
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown content type: \(type)")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let imageContent):
            try container.encode("image", forKey: .type)
            try container.encode(imageContent.data, forKey: .data)
            try container.encode(imageContent.mimeType, forKey: .mimeType)
        case .resource(let resourceContent):
            try container.encode("resource", forKey: .type)
            try container.encode(resourceContent.uri, forKey: .uri)
            try container.encodeIfPresent(resourceContent.mimeType, forKey: .mimeType)
        }
    }
}

public struct MCPImageContent: Codable, Sendable {
    public let data: String  // base64 encoded
    public let mimeType: String
    
    public init(data: String, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

public struct MCPResourceContent: Codable, Sendable {
    public let uri: String
    public let mimeType: String?
    
    public init(uri: String, mimeType: String? = nil) {
        self.uri = uri
        self.mimeType = mimeType
    }
}

// MARK: - Standard MCP Methods

/// Initialize request parameters
public struct MCPInitializeParams: Codable, Sendable {
    public let protocolVersion: String
    public let capabilities: MCPClientCapabilities
    public let clientInfo: MCPClientInfo
    
    public init(protocolVersion: String, capabilities: MCPClientCapabilities, clientInfo: MCPClientInfo) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.clientInfo = clientInfo
    }
}

public struct MCPClientCapabilities: Codable, Sendable {
    public let roots: MCPRootsCapability?
    public let sampling: [String: AnyCodable]?
    
    public init(roots: MCPRootsCapability? = nil, sampling: [String: AnyCodable]? = nil) {
        self.roots = roots
        self.sampling = sampling
    }
}

public struct MCPRootsCapability: Codable, Sendable {
    public let listChanged: Bool?
    
    public init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

public struct MCPClientInfo: Codable, Sendable {
    public let name: String
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

/// Initialize response result
public struct MCPInitializeResult: Codable, Sendable {
    public let protocolVersion: String
    public let capabilities: MCPServerCapabilities
    public let serverInfo: MCPServerInfo
    
    private enum CodingKeys: String, CodingKey {
        case protocolVersion, capabilities, serverInfo
    }
    
    public init(capabilities: MCPServerCapabilities, serverInfo: MCPServerInfo) {
        self.protocolVersion = "2024-11-05"
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

public struct MCPServerInfo: Codable, Sendable {
    public let name: String
    public let version: String
    
    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

// MARK: - MCP Protocol Handler

/// Core MCP protocol message processor
public actor MCPProtocolHandler {
    private let logger: Logger
    private let toolRegistry: MCPToolRegistry
    private var isInitialized = false
    private var clientInfo: MCPClientInfo?
    
    public init(logger: Logger, toolRegistry: MCPToolRegistry) {
        self.logger = logger
        self.toolRegistry = toolRegistry
    }
    
    /// Process incoming MCP request and return response
    public func processRequest(_ request: MCPRequest) async -> MCPResponse {
        logger.debug("Processing MCP request: \(request.method)")
        
        do {
            let result = try await handleMethod(request.method, params: request.params, id: request.id)
            return MCPResponse(id: request.id, result: result)
        } catch let error as MCPError {
            logger.error("MCP error: \(error.message)")
            return MCPResponse(id: request.id, error: error)
        } catch {
            logger.error("Unexpected error: \(error)")
            return MCPResponse(id: request.id, error: MCPError.internalError)
        }
    }
    
    private func handleMethod(_ method: String, params: [String: AnyCodable]?, id: RequestID) async throws -> AnyCodable {
        switch method {
        case "initialize":
            return try await handleInitialize(params: params)
        case "initialized":
            return try await handleInitialized()
        case "tools/list":
            return try await handleToolsList()
        case "tools/call":
            return try await handleToolsCall(params: params)
        case "ping":
            return AnyCodable("pong")
        default:
            throw MCPError.methodNotFound
        }
    }
    
    private func handleInitialize(params: [String: AnyCodable]?) async throws -> AnyCodable {
        guard params != nil else {
            throw MCPError.invalidParams
        }
        
        // Parse initialize parameters (simplified for now)
        let serverInfo = MCPServerInfo(
            name: "Swift iOS Automation Platform",
            version: "1.0.0"
        )
        
        let capabilities = MCPServerCapabilities(
            tools: MCPToolsCapability(listChanged: true),
            logging: MCPLoggingCapability(level: "info")
        )
        
        let result = MCPInitializeResult(
            capabilities: capabilities,
            serverInfo: serverInfo
        )
        
        isInitialized = true
        logger.info("MCP server initialized successfully")
        
        return AnyCodable(result)
    }
    
    private func handleInitialized() async throws -> AnyCodable {
        logger.info("MCP client initialization complete")
        return AnyCodable([String: String]())
    }
    
    private func handleToolsList() async throws -> AnyCodable {
        let tools = await toolRegistry.getAllTools()
        return AnyCodable(["tools": tools])
    }
    
    private func handleToolsCall(params: [String: AnyCodable]?) async throws -> AnyCodable {
        guard let params = params else {
            throw MCPError.invalidParams
        }
        
        // Extract tool name and arguments
        guard let nameValue = params["name"],
              let toolName = nameValue.value as? String else {
            throw MCPError.invalidParams
        }
        
        // Extract arguments more simply
        var arguments: [String: AnyCodable] = [:]
        if let argumentsValue = params["arguments"] {
            // Convert the arguments to a simple dictionary
            if let argumentsDict = argumentsValue.value as? [String: Any] {
                for (key, value) in argumentsDict {
                    // Convert basic types to AnyCodable
                    if let stringValue = value as? String {
                        arguments[key] = AnyCodable(stringValue)
                    } else if let intValue = value as? Int {
                        arguments[key] = AnyCodable(intValue)
                    } else if let boolValue = value as? Bool {
                        arguments[key] = AnyCodable(boolValue)
                    } else {
                        // Convert any other type to string
                        arguments[key] = AnyCodable(String(describing: value))
                    }
                }
            }
        }
        
        // Execute tool
        let result = try await toolRegistry.executeTool(name: toolName, arguments: arguments)
        return AnyCodable(result)
    }
} 