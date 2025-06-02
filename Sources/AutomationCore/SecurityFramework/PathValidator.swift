import Foundation

/// Utility for validating and resolving filesystem paths.
public struct PathValidator {
    private let allowedDirectories: [String]

    public init(allowedDirectories: [String]) {
        self.allowedDirectories = allowedDirectories.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        }
    }

    /// Resolve symlinks and standardize a path.
    public func resolvedPath(for path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// Check for path traversal components ("..") after standardization.
    public func isTraversalSafe(_ path: String) -> Bool {
        !URL(fileURLWithPath: path).standardized.pathComponents.contains("..")
    }

    /// Ensure the path resides within one of the allowed directories.
    public func isWhitelisted(_ path: String) -> Bool {
        let resolved = (try? resolvedPath(for: path)) ?? path
        return allowedDirectories.contains { resolved.hasPrefix($0) }
    }
}
