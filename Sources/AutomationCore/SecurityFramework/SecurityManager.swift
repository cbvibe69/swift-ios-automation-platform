import Foundation
import Logging

/// Manages security-related operations such as validating project paths and requesting
/// user permissions for file access.
public class SecurityManager {
    private let maximumSecurity: Bool
    private let logger: Logger

    public init(maximumSecurity: Bool, logger: Logger) throws {
        self.maximumSecurity = maximumSecurity
        self.logger = logger
    }

    /// Validate that a project path is allowed for operations.
    public func validateProjectPath(_ path: String) throws {
        logger.debug("validateProjectPath invoked with \(path)")
        throw MCPError.invalidProject("Validation not implemented for path \(path)")
    }

    /// Variant used by the server for project creation specifically.
    public func validateProjectCreationPath(_ path: String) throws {
        logger.debug("validateProjectCreationPath invoked with \(path)")
        throw MCPError.invalidProject("Creation path validation not implemented for \(path)")
    }

    /// Request access to files with a specified purpose.
    public func requestFileAccess(paths: [String], purpose: AccessPurpose) async throws -> FileAccessResult {
        logger.debug("requestFileAccess invoked for \(paths)")
        throw MCPError.securityViolation("File access request not implemented")
    }
}

/// Reason for requesting file access.
public enum AccessPurpose: Sendable {
    case buildAnalysis
    case projectCreation
    case custom(String)
}

/// Result of a file access request containing granted paths and any security bookmarks.
public struct FileAccessResult: Sendable {
    public let grantedPaths: [String]
    public let bookmarks: [SecurityBookmark]

    public init(grantedPaths: [String], bookmarks: [SecurityBookmark]) {
        self.grantedPaths = grantedPaths
        self.bookmarks = bookmarks
    }
}

/// Placeholder representing a security-scoped bookmark.
public struct SecurityBookmark: Sendable, Hashable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
