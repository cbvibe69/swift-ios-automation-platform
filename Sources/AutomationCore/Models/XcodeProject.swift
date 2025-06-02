import Foundation

/// Representation of an Xcode project.
public struct XcodeProject: Sendable, Hashable {
    public let name: String
    public let path: String
    public let scheme: String
    public let projectFile: XcodeProjectFile

    public init(name: String, path: String, scheme: String, projectFile: XcodeProjectFile) {
        self.name = name
        self.path = path
        self.scheme = scheme
        self.projectFile = projectFile
    }
}

/// Placeholder for the actual Xcode project file representation.
public struct XcodeProjectFile: Sendable, Hashable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
