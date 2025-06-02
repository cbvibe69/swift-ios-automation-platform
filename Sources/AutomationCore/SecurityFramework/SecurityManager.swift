import Foundation
import Logging

/// Errors that can occur during security validation.
public enum SecurityError: Error, Sendable {
    case pathTraversalDetected
    case unauthorizedDirectory
    case permissionDenied
}

/// Manages security-related operations such as validating project paths and requesting
/// user permissions for file access.
public class SecurityManager {
    private let maximumSecurity: Bool
    private let logger: Logger
    private let pathValidator: PathValidator
    private let sandboxManager: SandboxManager

    public init(maximumSecurity: Bool, logger: Logger) throws {
        self.maximumSecurity = maximumSecurity
        self.logger = logger
        self.pathValidator = PathValidator(allowedDirectories: [FileManager.default.currentDirectoryPath])
        self.sandboxManager = SandboxManager(logger: logger)
        self.sandboxManager.prepareSandbox()
    }

    /// Validate that a project path is allowed for operations.
    public func validateProjectPath(_ path: String) throws {
        logger.debug("validateProjectPath invoked with \(path)")
        let resolved = try pathValidator.resolvedPath(for: path)

        guard pathValidator.isTraversalSafe(resolved) else {
            logger.warning("Path traversal detected for \(path)")
            throw SecurityError.pathTraversalDetected
        }

        guard pathValidator.isWhitelisted(resolved) else {
            logger.warning("Path \(resolved) not within allowed directories")
            throw SecurityError.unauthorizedDirectory
        }
    }

    /// Variant used by the server for project creation specifically.
    public func validateProjectCreationPath(_ path: String) throws {
        logger.debug("validateProjectCreationPath invoked with \(path)")
        throw MCPError.unimplemented
    }

    /// Request access to files with a specified purpose.
    public func requestFileAccess(paths: [String], purpose: AccessPurpose) async throws -> FileAccessResult {
        logger.debug("requestFileAccess invoked for \(paths)")

        var granted: [String] = []
        var bookmarks: [SecurityBookmark] = []

        for path in paths {
            let resolved = try pathValidator.resolvedPath(for: path)

            guard pathValidator.isTraversalSafe(resolved) else {
                logger.warning("Path traversal detected for \(path)")
                throw SecurityError.pathTraversalDetected
            }

            if pathValidator.isWhitelisted(resolved) {
                granted.append(resolved)
                continue
            }

            guard await requestUserPermission(for: resolved, purpose: purpose) else {
                throw SecurityError.permissionDenied
            }

            granted.append(resolved)
            bookmarks.append(SecurityBookmark(url: URL(fileURLWithPath: resolved)))
        }

        return FileAccessResult(grantedPaths: granted, bookmarks: bookmarks)
    }

    // MARK: - Private Helpers

    private func requestUserPermission(for path: String, purpose: AccessPurpose) async -> Bool {
        print("Allow access to \(path) for \(describe(purpose))? [y/N] ", terminator: "")
        guard let response = readLine() else { return false }
        return response.lowercased().hasPrefix("y")
    }

    private func describe(_ purpose: AccessPurpose) -> String {
        switch purpose {
        case .buildAnalysis:
            return "build analysis"
        case .projectCreation:
            return "project creation"
        case .custom(let value):
            return value
        }
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
