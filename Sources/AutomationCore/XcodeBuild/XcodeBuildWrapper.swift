import Foundation
import Logging
#if os(macOS)
import Darwin
#endif

/// Comprehensive wrapper for xcodebuild command-line operations
public actor XcodeBuildWrapper {
    private let logger: Logger
    private let securityManager: SecurityManager?
    
    public init(logger: Logger, securityManager: SecurityManager? = nil) {
        self.logger = logger
        self.securityManager = securityManager
    }
    
    // MARK: - Build Operations
    
    /// Build a project with comprehensive error handling and optimization
    public func buildProject(
        at projectPath: String,
        scheme: String,
        destination: String = "platform=iOS Simulator,name=iPhone 15",
        configuration: BuildConfiguration = .debug,
        options: BuildOptions = BuildOptions()
    ) async throws -> BuildResult {
        
        logger.info("🔨 Building project: \(scheme) (\(configuration.rawValue))")
        
        // Security validation
        try await validateProjectPath(projectPath)
        
        // Prepare build command
        let command = try prepareBuildCommand(
            projectPath: projectPath,
            scheme: scheme,
            destination: destination,
            configuration: configuration,
            options: options
        )
        
        // Execute build with monitoring
        let startTime = ContinuousClock.now
        let result = try await executeXcodeBuild(command: command)
        let duration = startTime.duration(to: .now)
        
        // Parse and analyze results
        let buildResult = try parseBuildResult(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            duration: duration
        )
        
        logger.info("✅ Build completed in \(duration.formatted()) - Success: \(buildResult.success)")
        return buildResult
    }
    
    /// Run tests with detailed reporting
    public func runTests(
        at projectPath: String,
        scheme: String,
        destination: String = "platform=iOS Simulator,name=iPhone 15",
        options: TestOptions = TestOptions()
    ) async throws -> TestResult {
        
        logger.info("🧪 Running tests: \(scheme)")
        
        try await validateProjectPath(projectPath)
        
        let command = try prepareTestCommand(
            projectPath: projectPath,
            scheme: scheme,
            destination: destination,
            options: options
        )
        
        let startTime = ContinuousClock.now
        let result = try await executeXcodeBuild(command: command)
        let duration = startTime.duration(to: .now)
        
        let testResult = try parseTestResult(
            output: result.output,
            errorOutput: result.errorOutput,
            exitCode: result.exitCode,
            duration: duration
        )
        
        logger.info("🧪 Tests completed in \(duration.formatted()) - Passed: \(testResult.passedCount), Failed: \(testResult.failedCount)")
        return testResult
    }
    
    /// List available schemes in a project
    public func listSchemes(at projectPath: String) async throws -> [XcodeScheme] {
        logger.debug("📋 Listing schemes for project at: \(projectPath)")
        
        try await validateProjectPath(projectPath)
        
        let command = [
            "xcodebuild",
            "-list",
            "-json",
            projectPath.hasSuffix(".xcworkspace") ? "-workspace" : "-project",
            projectPath
        ]
        
        let result = try await executeCommand(command)
        guard result.exitCode == 0 else {
            throw XcodeBuildError.commandFailed("Failed to list schemes: \(result.errorOutput)")
        }
        
        return try parseSchemesList(from: result.output)
    }
    
    /// Get build settings for a scheme
    public func getBuildSettings(
        at projectPath: String,
        scheme: String,
        configuration: BuildConfiguration = .debug
    ) async throws -> [String: String] {
        
        logger.debug("⚙️ Getting build settings for \(scheme)")
        
        try await validateProjectPath(projectPath)
        
        let command = [
            "xcodebuild",
            projectPath.hasSuffix(".xcworkspace") ? "-workspace" : "-project",
            projectPath,
            "-scheme", scheme,
            "-configuration", configuration.rawValue,
            "-showBuildSettings",
            "-json"
        ]
        
        let result = try await executeCommand(command)
        guard result.exitCode == 0 else {
            throw XcodeBuildError.commandFailed("Failed to get build settings: \(result.errorOutput)")
        }
        
        return try parseBuildSettings(from: result.output)
    }
    
    // MARK: - Command Preparation
    
    private func prepareBuildCommand(
        projectPath: String,
        scheme: String,
        destination: String,
        configuration: BuildConfiguration,
        options: BuildOptions
    ) throws -> [String] {
        
        var command = ["xcodebuild"]
        
        // Project/workspace specification
        if projectPath.hasSuffix(".xcworkspace") {
            command.append(contentsOf: ["-workspace", projectPath])
        } else {
            command.append(contentsOf: ["-project", projectPath])
        }
        
        // Build parameters
        command.append(contentsOf: [
            "-scheme", scheme,
            "-configuration", configuration.rawValue,
            "-destination", destination
        ])
        
        // Build action
        if options.cleanBuild {
            command.append("clean")
        }
        command.append("build")
        
        // Additional options
        if options.allowProvisioningUpdates {
            command.append("-allowProvisioningUpdates")
        }
        
        if let derivedDataPath = options.derivedDataPath {
            command.append(contentsOf: ["-derivedDataPath", derivedDataPath])
        }
        
        if options.verbose {
            command.append("-verbose")
        }
        
        return command
    }
    
    private func prepareTestCommand(
        projectPath: String,
        scheme: String,
        destination: String,
        options: TestOptions
    ) throws -> [String] {
        
        var command = ["xcodebuild"]
        
        // Project/workspace specification
        if projectPath.hasSuffix(".xcworkspace") {
            command.append(contentsOf: ["-workspace", projectPath])
        } else {
            command.append(contentsOf: ["-project", projectPath])
        }
        
        // Test parameters
        command.append(contentsOf: [
            "-scheme", scheme,
            "-destination", destination,
            "test"
        ])
        
        // Test-specific options
        if let testSuite = options.testSuite {
            command.append(contentsOf: ["-only-testing", testSuite])
        }
        
        if let testClass = options.testClass {
            command.append(contentsOf: ["-only-testing", testClass])
        }
        
        if options.enableCodeCoverage {
            command.append("-enableCodeCoverage YES")
        }
        
        if let derivedDataPath = options.derivedDataPath {
            command.append(contentsOf: ["-derivedDataPath", derivedDataPath])
        }
        
        return command
    }
    
    // MARK: - Command Execution
    
    private func executeXcodeBuild(command: [String]) async throws -> ProcessResult {
        logger.debug("Executing: \(command.joined(separator: " "))")
        
        let result = try await executeCommand(command)
        
        // Log command output for debugging
        if !result.output.isEmpty {
            logger.debug("xcodebuild output: \(result.output.prefix(500))...")
        }
        
        if !result.errorOutput.isEmpty {
            logger.debug("xcodebuild errors: \(result.errorOutput.prefix(500))...")
        }
        
        return result
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
                continuation.resume(throwing: XcodeBuildError.processStartFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Result Parsing
    
    private func parseBuildResult(
        output: String,
        errorOutput: String,
        exitCode: Int,
        duration: Duration
    ) throws -> BuildResult {
        
        let success = exitCode == 0
        let errors = extractErrors(from: output + errorOutput)
        let warnings = extractWarnings(from: output + errorOutput)
        
        return BuildResult(
            success: success,
            duration: duration,
            errors: errors,
            warnings: warnings,
            rawOutput: output,
            rawErrorOutput: errorOutput
        )
    }
    
    private func parseTestResult(
        output: String,
        errorOutput: String,
        exitCode: Int,
        duration: Duration
    ) throws -> TestResult {
        
        let testCases = extractTestCases(from: output)
        let passedCount = testCases.filter { $0.status == .passed }.count
        let failedCount = testCases.filter { $0.status == .failed }.count
        
        return TestResult(
            success: exitCode == 0,
            duration: duration,
            testCases: testCases,
            passedCount: passedCount,
            failedCount: failedCount,
            rawOutput: output
        )
    }
    
    private func parseSchemesList(from output: String) throws -> [XcodeScheme] {
        guard let data = output.data(using: .utf8) else {
            throw XcodeBuildError.parseError("Invalid UTF-8 in schemes output")
        }
        
        struct SchemesResponse: Codable {
            let project: ProjectInfo?
            let workspace: WorkspaceInfo?
            
            struct ProjectInfo: Codable {
                let schemes: [String]
            }
            
            struct WorkspaceInfo: Codable {
                let schemes: [String]
            }
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(SchemesResponse.self, from: data)
        
        let schemeNames = response.project?.schemes ?? response.workspace?.schemes ?? []
        return schemeNames.map { XcodeScheme(name: $0) }
    }
    
    private func parseBuildSettings(from output: String) throws -> [String: String] {
        // Simplified build settings parsing - in production this would be more robust
        let lines = output.components(separatedBy: .newlines)
        var settings: [String: String] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let equalsRange = trimmed.range(of: " = ") {
                let key = String(trimmed[..<equalsRange.lowerBound])
                let value = String(trimmed[equalsRange.upperBound...])
                settings[key] = value
            }
        }
        
        return settings
    }
    
    // MARK: - Error and Warning Extraction
    
    private func extractErrors(from output: String) -> [BuildError] {
        let lines = output.components(separatedBy: .newlines)
        var errors: [BuildError] = []
        
        for line in lines {
            if line.contains("error:") {
                errors.append(BuildError(
                    message: line,
                    file: extractFilePath(from: line),
                    line: extractLineNumber(from: line)
                ))
            }
        }
        
        return errors
    }
    
    private func extractWarnings(from output: String) -> [BuildWarning] {
        let lines = output.components(separatedBy: .newlines)
        var warnings: [BuildWarning] = []
        
        for line in lines {
            if line.contains("warning:") {
                warnings.append(BuildWarning(
                    message: line,
                    file: extractFilePath(from: line),
                    line: extractLineNumber(from: line)
                ))
            }
        }
        
        return warnings
    }
    
    private func extractTestCases(from output: String) -> [TestCase] {
        let lines = output.components(separatedBy: .newlines)
        var testCases: [TestCase] = []
        
        for line in lines {
            if line.contains("Test Case") {
                if line.contains("passed") {
                    testCases.append(TestCase(
                        name: extractTestName(from: line),
                        status: .passed,
                        duration: extractTestDuration(from: line)
                    ))
                } else if line.contains("failed") {
                    testCases.append(TestCase(
                        name: extractTestName(from: line),
                        status: .failed,
                        duration: extractTestDuration(from: line),
                        failureMessage: extractFailureMessage(from: line)
                    ))
                }
            }
        }
        
        return testCases
    }
    
    // MARK: - Helper Methods
    
    private func extractFilePath(from line: String) -> String? {
        // Extract file path from error/warning line
        // Implementation would use regex or string parsing
        return nil
    }
    
    private func extractLineNumber(from line: String) -> Int? {
        // Extract line number from error/warning line
        return nil
    }
    
    private func extractTestName(from line: String) -> String {
        // Extract test name from test result line
        return line
    }
    
    private func extractTestDuration(from line: String) -> TimeInterval? {
        // Extract test duration from test result line
        return nil
    }
    
    private func extractFailureMessage(from line: String) -> String? {
        // Extract failure message from failed test line
        return nil
    }
    
    private func validateProjectPath(_ path: String) async throws {
        if let securityManager = securityManager {
            try securityManager.validateProjectPath(path)
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            throw XcodeBuildError.projectNotFound(path)
        }
        
        let isXcodeProject = path.hasSuffix(".xcodeproj") || path.hasSuffix(".xcworkspace")
        guard isXcodeProject else {
            throw XcodeBuildError.invalidProjectType(path)
        }
    }
}

// MARK: - Supporting Types

public enum BuildConfiguration: String, CaseIterable, Codable, Sendable {
    case debug = "Debug"
    case release = "Release"
}

public struct BuildOptions: Sendable {
    public let cleanBuild: Bool
    public let allowProvisioningUpdates: Bool
    public let derivedDataPath: String?
    public let verbose: Bool
    
    public init(
        cleanBuild: Bool = false,
        allowProvisioningUpdates: Bool = false,
        derivedDataPath: String? = nil,
        verbose: Bool = false
    ) {
        self.cleanBuild = cleanBuild
        self.allowProvisioningUpdates = allowProvisioningUpdates
        self.derivedDataPath = derivedDataPath
        self.verbose = verbose
    }
}

public struct TestOptions: Sendable {
    public let testSuite: String?
    public let testClass: String?
    public let enableCodeCoverage: Bool
    public let derivedDataPath: String?
    
    public init(
        testSuite: String? = nil,
        testClass: String? = nil,
        enableCodeCoverage: Bool = true,
        derivedDataPath: String? = nil
    ) {
        self.testSuite = testSuite
        self.testClass = testClass
        self.enableCodeCoverage = enableCodeCoverage
        self.derivedDataPath = derivedDataPath
    }
}

public struct BuildResult: Sendable {
    public let success: Bool
    public let duration: Duration
    public let errors: [BuildError]
    public let warnings: [BuildWarning]
    public let rawOutput: String
    public let rawErrorOutput: String
}

public struct TestResult: Sendable {
    public let success: Bool
    public let duration: Duration
    public let testCases: [TestCase]
    public let passedCount: Int
    public let failedCount: Int
    public let rawOutput: String
}

public struct BuildError: Sendable {
    public let message: String
    public let file: String?
    public let line: Int?
}

public struct BuildWarning: Sendable {
    public let message: String
    public let file: String?
    public let line: Int?
}

public struct TestCase: Sendable {
    public let name: String
    public let status: TestStatus
    public let duration: TimeInterval?
    public let failureMessage: String?
    
    public init(name: String, status: TestStatus, duration: TimeInterval? = nil, failureMessage: String? = nil) {
        self.name = name
        self.status = status
        self.duration = duration
        self.failureMessage = failureMessage
    }
}

public enum TestStatus: Sendable {
    case passed
    case failed
    case skipped
}

public struct XcodeScheme: Sendable {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

public struct ProcessResult: Sendable {
    public let output: String
    public let errorOutput: String
    public let exitCode: Int
}

public enum XcodeBuildError: Error, LocalizedError {
    case projectNotFound(String)
    case invalidProjectType(String)
    case commandFailed(String)
    case processStartFailed(String)
    case parseError(String)
    
    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let path):
            return "Project not found at path: \(path)"
        case .invalidProjectType(let path):
            return "Invalid project type at path: \(path)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .processStartFailed(let message):
            return "Failed to start process: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
} 