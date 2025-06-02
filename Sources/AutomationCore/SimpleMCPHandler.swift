import Foundation
import Logging

// MARK: - Simple MCP Handler with Tool Registry

/// Simple MCP implementation to get started
public final class SimpleMCPHandler {
    private let logger: Logger
    private let registry: MCPToolRegistry

    public init(logger: Logger, registry: MCPToolRegistry = MCPToolRegistry()) {
        self.logger = logger
        self.registry = registry
        // Register default tools asynchronously
        Task { await self.registerDefaultTools() }
    }

    // MARK: - Tool Registration

    private func registerDefaultTools() async {
        await registry.register(BuildProjectTool(handler: self))
        await registry.register(ListSimulatorsTool(logger: logger))
        await registry.register(GetProjectInfoTool(logger: logger))
        await registry.register(ValidateProjectTool())
    }

    // MARK: - JSON-RPC Handling

    /// Handle a JSON-RPC encoded request and route it to the appropriate tool.
    public func handleMessage(_ data: Data) async -> Data {
        do {
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let method = object["method"] as? String
            else {
                return errorResponse(id: nil, code: -32600, message: "Invalid request")
            }

            let id = object["id"] as? Int
            let paramsData: Data
            if let params = object["params"] {
                paramsData = try JSONSerialization.data(withJSONObject: params)
            } else {
                paramsData = Data("{}".utf8)
            }

            guard let tool = await registry.tool(named: method) else {
                return errorResponse(id: id, code: -32601, message: "Method not found")
            }

            let resultData = try await tool.handle(paramsData)
            return successResponse(id: id, result: resultData)
        } catch {
            return errorResponse(id: nil, code: -32000, message: error.localizedDescription)
        }
    }

    private func successResponse(id: Int?, result: Data) -> Data {
        var response: [String: Any] = ["jsonrpc": "2.0"]
        if let id = id { response["id"] = id }
        if let resultObject = try? JSONSerialization.jsonObject(with: result) {
            response["result"] = resultObject
        }
        return (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
    }

    private func errorResponse(id: Int?, code: Int, message: String) -> Data {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message]
        ]
        if let id = id { response["id"] = id }
        return (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
    }

    /// Handle a basic build request and run xcodebuild.
    public func handleBuildRequest(_ request: SimpleBuildRequest) async throws -> SimpleBuildResponse {
        // 1. Construct xcodebuild arguments
        var arguments: [String] = ["-scheme", request.scheme, "-project", request.projectPath]
        if let destination = request.destination {
            arguments += ["-destination", destination]
        }
        if let configuration = request.configuration {
            arguments += ["-configuration", configuration]
        }

        logger.info("Running xcodebuild \(arguments.joined(separator: " "))")

        // 2. Execute xcodebuild via subprocess
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        // 3. Parse output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(decoding: stdoutData, as: UTF8.self)
        let stderr = String(decoding: stderrData, as: UTF8.self)

        // 4. Return structured response
        return SimpleBuildResponse(success: process.terminationStatus == 0,
                                   stdout: stdout,
                                   stderr: stderr)
    }
}

/// Minimal build request structure expected from incoming MCP messages.
public struct SimpleBuildRequest: Codable {
    public let projectPath: String
    public let scheme: String
    public let destination: String?
    public let configuration: String?
}

/// Minimal build response returned to MCP clients.
public struct SimpleBuildResponse: Codable {
    public let success: Bool
    public let stdout: String
    public let stderr: String
}

// MARK: - Additional Tool Requests/Responses

struct ListSimulatorsRequest: Codable {}
struct ListSimulatorsResponse: Codable {
    let simulators: [SimulatorDevice]
}

struct GetProjectInfoRequest: Codable { let projectPath: String }
struct GetProjectInfoResponse: Codable { let schemes: [String] }

struct ValidateProjectRequest: Codable { let projectPath: String }
struct ValidateProjectResponse: Codable { let valid: Bool; let message: String }

// MARK: - MCP Tool Implementations

struct BuildProjectTool: MCPTool {
    typealias Request = SimpleBuildRequest
    typealias Response = SimpleBuildResponse

    let handler: SimpleMCPHandler
    var name: String { "build_project" }

    func handle(request: SimpleBuildRequest) async throws -> SimpleBuildResponse {
        try await handler.handleBuildRequest(request)
    }
}

struct ListSimulatorsTool: MCPTool {
    struct Request: Codable {}
    typealias Response = ListSimulatorsResponse

    let logger: Logger
    var name: String { "list_simulators" }

    func handle(request: Request) async throws -> ListSimulatorsResponse {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "available", "-j"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var result: [SimulatorDevice] = []
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let devices = json["devices"] as? [String: Any] {
            for (runtime, value) in devices {
                if let list = value as? [[String: Any]] {
                    for dev in list {
                        guard (dev["isAvailable"] as? Bool) == true else { continue }
                        if let name = dev["name"] as? String,
                           let udid = dev["udid"] as? String {
                            let type = dev["deviceTypeIdentifier"] as? String ?? ""
                            result.append(SimulatorDevice(id: udid, name: name, runtime: runtime, deviceType: type))
                        }
                    }
                }
            }
        }
        return ListSimulatorsResponse(simulators: result)
    }
}

struct GetProjectInfoTool: MCPTool {
    typealias Request = GetProjectInfoRequest
    typealias Response = GetProjectInfoResponse

    let logger: Logger
    var name: String { "get_project_info" }

    func handle(request: GetProjectInfoRequest) async throws -> GetProjectInfoResponse {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-list", "-json", "-project", request.projectPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let project = json["project"] as? [String: Any],
           let schemes = project["schemes"] as? [String] {
            return GetProjectInfoResponse(schemes: schemes)
        }
        return GetProjectInfoResponse(schemes: [])
    }
}

struct ValidateProjectTool: MCPTool {
    typealias Request = ValidateProjectRequest
    typealias Response = ValidateProjectResponse

    var name: String { "validate_project" }

    func handle(request: ValidateProjectRequest) async throws -> ValidateProjectResponse {
        let exists = FileManager.default.fileExists(atPath: request.projectPath)
        let message = exists ? "Project exists" : "Project not found"
        return ValidateProjectResponse(valid: exists, message: message)
    }
}
