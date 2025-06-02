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
    public func executeWithResourceControl<T>(_ operation: () async throws -> T) async throws -> T {
        logger.debug("executeWithResourceControl invoked")

        while true {
            let usage = await monitor.snapshot()
            let cpuPct = usage.cpuUsage * 100
            let memPct = Double(usage.memoryUsedBytes) / Double(hardwareSpec.totalMemoryGB * 1024 * 1024 * 1024) * 100

            if cpuPct < Double(maxUtilization) && memPct < Double(maxUtilization) {
                break
            }

            logger.debug("Resources busy - CPU: \(cpuPct)% MEM: \(memPct)%")
            try await Task.sleep(for: .seconds(1))
        }

        return try await operation()
    }

    /// Determine optimal simulator count given requested devices and optional limit.
    public func calculateOptimalSimulatorCount(requestedDevices: [SimulatorDevice], maxConcurrent: Int?) async throws -> Int {
        logger.debug("calculateOptimalSimulatorCount invoked")

        let usage = await monitor.snapshot()
        var optimal = hardwareSpec.recommendedSimulators

        let cpuHeadroom = Int(Double(hardwareSpec.cpuCores) * (1 - usage.cpuUsage))
        let memHeadroom = Int((Double(hardwareSpec.totalMemoryGB) * 1024 * 1024 * 1024 - Double(usage.memoryUsedBytes)) / Double(2 * 1024 * 1024 * 1024))

        optimal = min(optimal, cpuHeadroom, memHeadroom)

        if hardwareSpec.isM2Max {
            optimal += 2
        }

        if let maxConcurrent = maxConcurrent {
            optimal = min(optimal, maxConcurrent)
        }

        optimal = max(optimal, requestedDevices.count)
        optimal = min(max(optimal, 1), 12)

        return optimal
    }

    /// Placeholder for resource optimization loop called by the server.
    public func optimizeResourceAllocation() async {
        logger.debug("optimizeResourceAllocation invoked")
        let usage = await monitor.snapshot()
        logger.trace("CPU usage: \(usage.cpuUsage), mem used: \(usage.memoryUsedBytes)")
    }
}
