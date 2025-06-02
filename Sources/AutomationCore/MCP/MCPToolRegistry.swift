import Foundation

/// Registry storing available MCP tools.
public actor MCPToolRegistry {
    private var tools: [String: AnyMCPTool] = [:]

    public init() {}

    /// Register a new tool. Existing tool with the same name will be replaced.
    public func register<T: MCPTool>(_ tool: T) {
        tools[tool.name] = AnyMCPTool(tool)
    }

    /// Retrieve a registered tool by name.
    public func tool(named name: String) -> AnyMCPTool? {
        tools[name]
    }
}
