import Foundation
import Logging

/// Simple MCP implementation to get started
public final class SimpleMCPHandler {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
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
