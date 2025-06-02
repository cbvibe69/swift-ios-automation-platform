import Foundation
import Logging
import Dispatch

/// Real-time file system monitoring with intelligent change detection
public actor FileSystemMonitor {
    private let logger: Logger
    private var watchedPaths: [String: DispatchSourceFileSystemObject] = [:]
    private var changeHandlers: [String: @Sendable (FileChangeEvent) -> Void] = [:]
    private let monitorQueue = DispatchQueue(label: "com.automation.filemonitor", qos: .background)
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    deinit {
        // Use detached task to avoid capture issues
        Task.detached { [watchedPaths] in
            for (_, source) in watchedPaths {
                source.cancel()
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Start monitoring a directory for changes
    public func startMonitoring(
        path: String,
        recursive: Bool = true,
        changeHandler: @escaping @Sendable (FileChangeEvent) -> Void
    ) async throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw FileSystemMonitorError.pathNotFound(path)
        }
        
        logger.info("📁 Starting file system monitoring: \(path)")
        
        // Stop existing monitoring for this path
        await stopMonitoring(path: path)
        
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            throw FileSystemMonitorError.cannotOpenPath(path)
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: monitorQueue
        )
        
        // Capture path and weak self to avoid retain cycles
        let monitoredPath = path
        source.setEventHandler { [weak self] in
            let event = source.data
            Task { @MainActor in
                await self?.handleFileSystemEvent(path: monitoredPath, event: event, changeHandler: changeHandler)
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        watchedPaths[path] = source
        changeHandlers[path] = changeHandler
        
        source.resume()
        
        // If recursive, set up monitoring for subdirectories
        if recursive {
            try await setupRecursiveMonitoring(rootPath: path, changeHandler: changeHandler)
        }
    }
    
    /// Stop monitoring a specific path
    public func stopMonitoring(path: String) async {
        guard let source = watchedPaths[path] else { return }
        
        logger.debug("🛑 Stopping file monitoring: \(path)")
        source.cancel()
        watchedPaths.removeValue(forKey: path)
        changeHandlers.removeValue(forKey: path)
    }
    
    /// Stop all file system monitoring
    public func stopAllMonitoring() async {
        logger.info("🛑 Stopping all file system monitoring")
        
        for (_, source) in watchedPaths {
            source.cancel()
        }
        
        watchedPaths.removeAll()
        changeHandlers.removeAll()
    }
    
    /// Get currently monitored paths
    public func getMonitoredPaths() async -> [String] {
        return Array(watchedPaths.keys)
    }
    
    // MARK: - Intelligent Project Monitoring
    
    /// Start smart monitoring for an Xcode project
    public func startProjectMonitoring(
        projectPath: String,
        onSourceChange: @escaping @Sendable (ProjectChangeEvent) -> Void
    ) async throws {
        logger.info("🏗️ Starting intelligent project monitoring: \(projectPath)")
        
        try await startMonitoring(path: projectPath, recursive: true) { [weak self] event in
            Task { @MainActor in
                await self?.analyzeProjectChange(projectPath: projectPath, event: event, handler: onSourceChange)
            }
        }
    }
    
    /// Monitor build logs in real-time
    public func startBuildLogMonitoring(
        derivedDataPath: String?,
        onLogChange: @escaping @Sendable (BuildLogEvent) -> Void
    ) async throws {
        let logPath = derivedDataPath ?? NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        
        logger.info("📋 Starting build log monitoring: \(logPath)")
        
        try await startMonitoring(path: logPath, recursive: true) { event in
            if event.path.contains("Logs") || event.path.hasSuffix(".xcactivitylog") {
                let logEvent = BuildLogEvent(
                    path: event.path,
                    changeType: event.changeType,
                    timestamp: event.timestamp
                )
                onLogChange(logEvent)
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func handleFileSystemEvent(
        path: String,
        event: DispatchSource.FileSystemEvent,
        changeHandler: @escaping @Sendable (FileChangeEvent) -> Void
    ) async {
        let changeType = await interpretChangeType(from: event)
        
        let changeEvent = FileChangeEvent(
            path: path,
            changeType: changeType,
            timestamp: Date(),
            metadata: await extractMetadata(for: path)
        )
        
        logger.debug("📁 File change detected: \(path) - \(changeType)")
        changeHandler(changeEvent)
    }
    
    private func interpretChangeType(from event: DispatchSource.FileSystemEvent) -> FileChangeType {
        if event.contains(.write) {
            return .modified
        } else if event.contains(.delete) {
            return .deleted
        } else if event.contains(.rename) {
            return .renamed
        } else if event.contains(.revoke) {
            return .permissionChanged
        } else {
            return .unknown
        }
    }
    
    private func extractMetadata(for path: String) -> FileMetadata {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return FileMetadata(
                size: attributes[.size] as? UInt64 ?? 0,
                modificationDate: attributes[.modificationDate] as? Date ?? Date(),
                fileType: attributes[.type] as? FileAttributeType ?? .typeUnknown
            )
        } catch {
            return FileMetadata(size: 0, modificationDate: Date(), fileType: .typeUnknown)
        }
    }
    
    private func setupRecursiveMonitoring(
        rootPath: String,
        changeHandler: @escaping @Sendable (FileChangeEvent) -> Void
    ) async throws {
        let fileManager = FileManager.default
        
        // Use sync enumeration to avoid async iteration issues
        let contents = try fileManager.contentsOfDirectory(atPath: rootPath)
        
        for item in contents {
            let fullPath = rootPath + "/" + item
            
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                // Skip common directories we don't want to monitor
                if shouldSkipDirectory(item) { continue }
                
                try await startMonitoring(path: fullPath, recursive: false, changeHandler: changeHandler)
            }
        }
    }
    
    private func shouldSkipDirectory(_ path: String) -> Bool {
        let skipPaths = [
            ".git", ".build", "DerivedData", ".swiftpm",
            "node_modules", "Pods", ".DS_Store"
        ]
        
        return skipPaths.contains { path.contains($0) }
    }
    
    private func analyzeProjectChange(
        projectPath: String,
        event: FileChangeEvent,
        handler: @escaping @Sendable (ProjectChangeEvent) -> Void
    ) async {
        let changeCategory = await categorizeProjectChange(event: event)
        let impact = await assessChangeImpact(event: event, category: changeCategory)
        
        let projectEvent = ProjectChangeEvent(
            originalEvent: event,
            category: changeCategory,
            impact: impact,
            recommendedActions: await generateRecommendations(for: changeCategory, impact: impact)
        )
        
        logger.info("🔄 Project change: \(changeCategory) - Impact: \(impact)")
        handler(projectEvent)
    }
    
    private func categorizeProjectChange(event: FileChangeEvent) -> ProjectChangeCategory {
        let path = event.path.lowercased()
        
        if path.hasSuffix(".swift") {
            return .sourceCode
        } else if path.contains("package.swift") || path.contains("podfile") {
            return .dependencies
        } else if path.contains(".xcodeproj") || path.contains(".xcworkspace") {
            return .projectConfiguration
        } else if path.contains("test") && path.hasSuffix(".swift") {
            return .tests
        } else if path.contains("resource") || path.hasSuffix(".strings") || path.hasSuffix(".plist") {
            return .resources
        } else if path.contains("build") || path.contains("derived") {
            return .buildArtifacts
        } else {
            return .other
        }
    }
    
    private func assessChangeImpact(event: FileChangeEvent, category: ProjectChangeCategory) -> ChangeImpact {
        switch category {
        case .sourceCode:
            return event.changeType == .modified ? .medium : .high
        case .dependencies:
            return .high // Dependency changes usually require rebuild
        case .projectConfiguration:
            return .high // Project settings affect everything
        case .tests:
            return .low // Test changes don't affect main code
        case .resources:
            return .low // Resources rarely affect compilation
        case .buildArtifacts:
            return .none // Build artifacts are automatically managed
        case .other:
            return .low
        }
    }
    
    private func generateRecommendations(
        for category: ProjectChangeCategory,
        impact: ChangeImpact
    ) -> [String] {
        var recommendations: [String] = []
        
        switch category {
        case .sourceCode:
            if impact == .high {
                recommendations.append("Consider running incremental build")
                recommendations.append("Check for syntax errors")
            } else {
                recommendations.append("Quick build validation recommended")
            }
            
        case .dependencies:
            recommendations.append("Full rebuild required")
            recommendations.append("Update Package.resolved if using SPM")
            recommendations.append("Clear derived data for clean state")
            
        case .projectConfiguration:
            recommendations.append("Full rebuild recommended")
            recommendations.append("Verify build settings changes")
            
        case .tests:
            recommendations.append("Run affected test suite")
            recommendations.append("Consider test-driven development")
            
        default:
            break
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public struct FileChangeEvent: Sendable {
    public let path: String
    public let changeType: FileChangeType
    public let timestamp: Date
    public let metadata: FileMetadata
}

public enum FileChangeType: Sendable {
    case modified
    case deleted
    case renamed
    case permissionChanged
    case unknown
}

public struct FileMetadata: Sendable {
    public let size: UInt64
    public let modificationDate: Date
    public let fileType: FileAttributeType
}

public struct ProjectChangeEvent: Sendable {
    public let originalEvent: FileChangeEvent
    public let category: ProjectChangeCategory
    public let impact: ChangeImpact
    public let recommendedActions: [String]
}

public enum ProjectChangeCategory: Sendable {
    case sourceCode
    case dependencies
    case projectConfiguration
    case tests
    case resources
    case buildArtifacts
    case other
}

public enum ChangeImpact: Sendable {
    case none
    case low
    case medium
    case high
}

public struct BuildLogEvent: Sendable {
    public let path: String
    public let changeType: FileChangeType
    public let timestamp: Date
}

public enum FileSystemMonitorError: Error, LocalizedError {
    case pathNotFound(String)
    case cannotOpenPath(String)
    case enumerationFailed(String)
    case permissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .cannotOpenPath(let path):
            return "Cannot open path for monitoring: \(path)"
        case .enumerationFailed(let path):
            return "Failed to enumerate directory: \(path)"
        case .permissionDenied(let path):
            return "Permission denied for path: \(path)"
        }
    }
} 