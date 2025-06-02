import Foundation

/// Result from a build operation.
public struct BuildResult: Sendable {
    public let success: Bool
    public let duration: Duration
    public let errors: [BuildError]
    public let errorAnalysis: ErrorAnalysis?
    public let performance: PerformanceMetrics

    public init(success: Bool, duration: Duration, errors: [BuildError], errorAnalysis: ErrorAnalysis?, performance: PerformanceMetrics) {
        self.success = success
        self.duration = duration
        self.errors = errors
        self.errorAnalysis = errorAnalysis
        self.performance = performance
    }
}

/// Placeholder representing a build error.
public struct BuildError: Sendable, Hashable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

/// Placeholder describing analysis of build errors.
public struct ErrorAnalysis: Sendable {
    public let summary: String

    public init(summary: String) {
        self.summary = summary
    }
}

/// Placeholder for build performance metrics.
public struct PerformanceMetrics: Sendable {
    public let cpuTime: Duration
    public let memoryUsageMB: Int

    public init(cpuTime: Duration, memoryUsageMB: Int) {
        self.cpuTime = cpuTime
        self.memoryUsageMB = memoryUsageMB
    }
}
