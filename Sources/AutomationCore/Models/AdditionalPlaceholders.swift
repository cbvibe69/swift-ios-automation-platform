import Foundation

// MARK: - Project Options
public struct ProjectOptions: Sendable {
    public let derivedDataPath: String?
    public let verbose: Bool
    
    public init(derivedDataPath: String? = nil, verbose: Bool = false) {
        self.derivedDataPath = derivedDataPath
        self.verbose = verbose
    }
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

// MARK: - Error Analysis
public struct ErrorAnalysis: Sendable {
    public let categoryBreakdown: [String: Int]
    public let suggestions: [String]
    
    public init(categoryBreakdown: [String: Int], suggestions: [String]) {
        self.categoryBreakdown = categoryBreakdown
        self.suggestions = suggestions
    }
}

// MARK: - Performance Metrics
public struct PerformanceMetrics: Sendable {
    public let buildTime: TimeInterval
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let diskIO: Double
    
    public init(buildTime: TimeInterval, cpuUsage: Double, memoryUsage: Double, diskIO: Double) {
        self.buildTime = buildTime
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskIO = diskIO
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

// MARK: - Hardware Specifications
public struct HardwareSpec: Sendable {
    public let cpuCores: Int
    public let totalMemoryGB: Int
    public let architecture: String
    
    public init(cpuCores: Int, totalMemoryGB: Int, architecture: String) {
        self.cpuCores = cpuCores
        self.totalMemoryGB = totalMemoryGB
        self.architecture = architecture
    }
}

// MARK: - Resource Usage
public struct ResourceUsage: Sendable {
    public let cpuUsage: Double
    public let memoryUsedBytes: UInt64
    public let diskUsage: Double
    
    public init(cpuUsage: Double, memoryUsedBytes: UInt64, diskUsage: Double) {
        self.cpuUsage = cpuUsage
        self.memoryUsedBytes = memoryUsedBytes
        self.diskUsage = diskUsage
    }
}

// MARK: - Hardware Detection
public struct HardwareDetection {
    public static func cpuCoreCount() -> Int {
        return ProcessInfo.processInfo.processorCount
    }
    
    public static func memorySize() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }
    
    public static func architecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
    
    public static func isAppleSilicon() -> Bool {
        return architecture() == "arm64"
    }
    
    public static func isMacStudioM2Max() -> Bool {
        // Simple heuristic: ARM64 with high core count and memory
        let cores = cpuCoreCount()
        let memoryGB = memorySize() / (1024 * 1024 * 1024)
        return isAppleSilicon() && cores >= 10 && memoryGB >= 32
    }
}

// MARK: - Resource Monitor
public actor ResourceMonitor {
    public init() {}
    
    public func getCurrentUsage() async -> ResourceUsage {
        // Simplified implementation for now
        return ResourceUsage(
            cpuUsage: 0.3, // 30% CPU usage
            memoryUsedBytes: 4 * 1024 * 1024 * 1024, // 4GB
            diskUsage: 0.5 // 50% disk usage
        )
    }
    
    public func snapshot() async -> ResourceUsage {
        return await getCurrentUsage()
    }
}

// MARK: - Security Manager
public struct SecurityManager {
    public init() {}
    
    public func validateProjectPath(_ path: String) throws {
        // Basic path validation
        guard !path.isEmpty else {
            throw MCPError.securityViolation("Empty project path")
        }
        
        guard !path.contains("..") else {
            throw MCPError.securityViolation("Path traversal not allowed")
        }
    }
}

// MARK: - Simulator Device
public struct SimulatorDevice: Sendable, Codable {
    public let udid: String
    public let name: String
    public let deviceType: String
    public let runtime: String
    public let state: String
    
    public init(udid: String, name: String, deviceType: String, runtime: String, state: String) {
        self.udid = udid
        self.name = name
        self.deviceType = deviceType
        self.runtime = runtime
        self.state = state
    }
}
