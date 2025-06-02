import Foundation

// MARK: - Build Configuration
public enum BuildConfiguration: Sendable {
    case debug
    case release
}

// MARK: - Project Options
public struct ProjectOptions: Sendable {
    public init() {}
}

public struct ProjectCreationResult: Sendable {
    public let project: XcodeProject

    public init(project: XcodeProject) {
        self.project = project
    }
}

// MARK: - Simulator Result
public struct SimulatorLaunchResult: Sendable {
    public let launchedDevices: [SimulatorDevice]

    public init(launchedDevices: [SimulatorDevice]) {
        self.launchedDevices = launchedDevices
    }
}

// MARK: - UI Test Result
public struct UITestResult: Sendable {
    public let success: Bool
    public init(success: Bool) {
        self.success = success
    }
}

// MARK: - Raw Build Result
public struct RawBuildResult: Sendable {
    public let output: String
    public let performance: PerformanceMetrics

    public init(output: String, performance: PerformanceMetrics) {
        self.output = output
        self.performance = performance
    }
}

// MARK: - File Operations
public enum FileOperation: Sendable {
    case copy
    case move
    case delete
}

public struct FileOperationResult: Sendable {
    public let success: Bool
    public init(success: Bool) {
        self.success = success
    }
}
