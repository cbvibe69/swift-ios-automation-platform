import Foundation

/// Protocol representing an MCP tool that can handle requests and produce responses.
public protocol MCPTool {
    associatedtype Request: Codable
    associatedtype Response: Codable

    /// Name used to invoke this tool via JSON-RPC `method` field.
    var name: String { get }

    /// Handle a strongly typed request and return a response.
    func handle(request: Request) async throws -> Response
}

/// Type-erased wrapper used by `MCPToolRegistry` to store heterogeneous tools.
public struct AnyMCPTool {
    public let name: String
    private let handler: (Data) async throws -> Data

    public init<T: MCPTool>(_ tool: T) {
        self.name = tool.name
        self.handler = { data in
            let decoder = JSONDecoder()
            let request = try decoder.decode(T.Request.self, from: data)
            let response = try await tool.handle(request: request)
            let encoder = JSONEncoder()
            return try encoder.encode(response)
        }
    }

    /// Execute the tool with raw JSON parameter data and return encoded result.
    func handle(_ data: Data) async throws -> Data {
        try await handler(data)
    }
}
