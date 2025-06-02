import Foundation
import Logging

/// Actor responsible for managing system resources for concurrent operations.
public actor ResourceManager {
    private let hardwareSpec: HardwareSpec
    private let maxUtilization: Int
    private let logger: Logger
    private let monitor: ResourceMonitor

    public init(hardwareSpec: HardwareSpec, maxUtilization: Int, logger: Logger) async throws {
        self.hardwareSpec = hardwareSpec
        self.maxUtilization = maxUtilization
        self.logger = logger
        self.monitor = ResourceMonitor()
    }

    /// Execute an operation while respecting resource limits.
    public func executeWithResourceControl<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        logger.debug("executeWithResourceControl invoked")

        let usage = await monitor.getCurrentUsage()
        let concurrency = await calculateOptimalConcurrency(currentUsage: usage)

        guard concurrency > 0 else {
            logger.warning("Resource exhaustion detected, waiting for resources to free up")
            // In a real implementation, we'd wait or queue the operation
            throw MCPError.resourceExhausted("System resources are currently exhausted")
        }

        return try await operation()
    }

    private func calculateOptimalConcurrency(currentUsage: ResourceUsage) async -> Int {
        var optimal = hardwareSpec.cpuCores

        let cpuHeadroom = Int(Double(hardwareSpec.cpuCores) * (1 - currentUsage.cpuUsage))
        
        // Break up the complex memory calculation
        let totalMemoryBytes = Double(hardwareSpec.totalMemoryGB) * 1024 * 1024 * 1024
        let availableMemoryBytes = totalMemoryBytes - Double(currentUsage.memoryUsedBytes)
        let memoryPerProcess = Double(2 * 1024 * 1024 * 1024) // 2GB per process
        let memHeadroom = Int(availableMemoryBytes / memoryPerProcess)

        optimal = min(optimal, cpuHeadroom, memHeadroom)

        return max(1, optimal)
    }

    /// Determine optimal simulator count given requested devices and optional limit.
    public func calculateOptimalSimulatorCount(requestedDevices: Int, limit: Int? = nil) async -> Int {
        let usage = await monitor.getCurrentUsage()
        var optimal = AutomationCore.calculateOptimalSimulatorCount(hardwareSpec: hardwareSpec, reservedMemoryGB: 4)

        // Apply CPU and memory constraints
        let cpuHeadroom = Int(Double(hardwareSpec.cpuCores) * (1 - usage.cpuUsage))
        let totalMemoryBytes = Double(hardwareSpec.totalMemoryGB) * 1024 * 1024 * 1024
        let availableMemoryBytes = totalMemoryBytes - Double(usage.memoryUsedBytes)
        let memoryPerSimulator = Double(2 * 1024 * 1024 * 1024) // 2GB per simulator
        let memHeadroom = Int(availableMemoryBytes / memoryPerSimulator)

        optimal = min(optimal, cpuHeadroom, memHeadroom)

        // Apply Apple Silicon optimizations
        if hardwareSpec.architecture == "arm64" {
            optimal += 2 // Apple Silicon can handle more simulators
        }

        // Apply requested constraints
        optimal = min(optimal, requestedDevices)
        if let limit = limit {
            optimal = min(optimal, limit)
        }

        return max(1, optimal)
    }

    /// Get current resource state for build intelligence optimization
    public func getCurrentResourceState() async -> ResourceState {
        let usage = await monitor.getCurrentUsage()
        let totalMemoryBytes = Double(hardwareSpec.totalMemoryGB) * 1024 * 1024 * 1024
        let availableMemoryBytes = totalMemoryBytes - Double(usage.memoryUsedBytes)
        let availableMemoryGB = availableMemoryBytes / (1024 * 1024 * 1024)
        
        return ResourceState(
            cpuCoreCount: hardwareSpec.cpuCores,
            availableMemoryGB: availableMemoryGB
        )
    }

    /// Placeholder for resource optimization functionality.
    public func optimizeResourceAllocation() async {
        logger.debug("optimizeResourceAllocation invoked")
        let usage = await monitor.getCurrentUsage()
        logger.trace("CPU usage: \(usage.cpuUsage), mem used: \(usage.memoryUsedBytes)")
    }
}

// MARK: - Supporting Types for Build Intelligence

public struct ResourceState: Sendable {
    public let cpuCoreCount: Int
    public let availableMemoryGB: Double
    
    public init(cpuCoreCount: Int, availableMemoryGB: Double) {
        self.cpuCoreCount = cpuCoreCount
        self.availableMemoryGB = availableMemoryGB
    }
}
