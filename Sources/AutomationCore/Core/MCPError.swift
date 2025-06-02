import Foundation

/// Centralized error type for the automation platform.
public enum MCPError: Error {
    /// Feature or API has not been implemented yet.
    case unimplemented
    /// Provided project path or configuration is invalid.
    case invalidProject(String)
    /// Build process failed with the given reason.
    case buildFailed(String)
    /// Security policy was violated or permission denied.
    case securityViolation(String)
    /// Required system resources are unavailable.
    case resourceExhausted
    /// Arguments provided to a command are invalid.
    case invalidArguments(String)
}

extension MCPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unimplemented:
            return "The requested functionality is not implemented."
        case .invalidProject(let message):
            return "Invalid project: \(message)"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .securityViolation(let message):
            return "Security violation: \(message)"
        case .resourceExhausted:
            return "System resources are exhausted."
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unimplemented:
            return "Update the application or check the documentation for upcoming features."
        case .invalidProject:
            return "Verify the project path and configuration."
        case .buildFailed:
            return "Inspect build logs for details and resolve any errors."
        case .securityViolation:
            return "Review security settings and required permissions."
        case .resourceExhausted:
            return "Reduce concurrent workload or free system resources."
        case .invalidArguments:
            return "Check the provided arguments for correctness."
        }
    }
}

extension MCPError: RecoverableError {
    public var recoveryOptions: [String] { ["OK"] }

    public func attemptRecovery(optionIndex: Int) -> Bool {
        // No automatic recovery available yet.
        false
    }
}
